"""
Method 2: GPTQ W4 quantization (implemented from scratch).

GPTQ uses second-order (Hessian) information H = 2·X^T·X to minimize the
layerwise reconstruction error. Weights are updated column-by-column:
  Q[:,i]     = round4(W[:,i])
  W[:,i+1:] -= (W[:,i] - Q[:,i]) / H^{-1}[i,i]  ·  H^{-1}[i, i+1:]

Implementation details:
  - Hessians accumulated online (one hook per Linear, CPU storage)
  - Block processing (block_size=128) for GPU efficiency
  - Asymmetric 4-bit, group_size=128, damp=0.01

Gate 1: fake quant logits comparison (W4 asym, activations float32)
Gate 2: W4A16 actual quantization — instructions printed if Gate 1 passes

Usage:
    cd /home/yangkai/workspace/xx_gemma
    python quantization/quant_gptq.py
"""

import json
import sys
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM

from compare_logits import load_eval_prompts, collect_logits, compute_metrics, print_results

MODEL_PATH = "/gemma/models/gemma3-sft"
CALIB_FILE = "quantization/data/calibration_data.jsonl"
N_EVAL     = 50
N_CALIB    = 512
GROUP_SIZE = 128
BLOCK_SIZE = 128
VOCAB_SIZE = 262144
DAMP       = 0.01


# ── Quantization helpers ────────────────────────────────────────────────────

def group_scales_zp(W: torch.Tensor, group_size: int):
    """Return per-group asymmetric 4-bit (scale, zp) lists from original W."""
    _, n_in = W.shape
    scales, zps = [], []
    for g in range(0, n_in, group_size):
        w_g   = W[:, g : g + group_size]
        w_min = w_g.min(dim=1).values
        w_max = w_g.max(dim=1).values
        s  = (w_max - w_min).clamp(min=1e-8) / 15.0
        zp = (-w_min / s).round().clamp(0, 15)
        scales.append(s)
        zps.append(zp)
    return scales, zps


def quant_dequant(w: torch.Tensor, scale: torch.Tensor, zp: torch.Tensor) -> torch.Tensor:
    q = (w / scale + zp).round().clamp(0, 15)
    return (q - zp) * scale


# ── GPTQ core ───────────────────────────────────────────────────────────────

def gptq_quantize(W: torch.Tensor, H: torch.Tensor) -> torch.Tensor:
    """
    GPTQ for one weight matrix.

    W : [out_features, in_features]  float32, on device
    H : [in_features, in_features]   accumulated 2·X^T·X (CPU → moved here)
    Returns fake-quantized W_q (same shape, float32).
    """
    device = W.device
    W = W.clone().float()
    H = H.to(device).float()
    _, n_in = W.shape
    dead = torch.diag(H) == 0
    H[dead, dead] = 1
    W[:, dead]    = 0

    # Diagonal damping
    H += DAMP * torch.diag(H).mean() * torch.eye(n_in, device=device)

    # Upper-triangular Cholesky factor of H^{-1}
    try:
        H_chol = torch.linalg.cholesky(H)
        H_inv  = torch.cholesky_inverse(H_chol)
        Hinv_U = torch.linalg.cholesky(H_inv, upper=True)
    except torch.linalg.LinAlgError:
        H     += 1e-3 * torch.eye(n_in, device=device)
        H_chol = torch.linalg.cholesky(H)
        H_inv  = torch.cholesky_inverse(H_chol)
        Hinv_U = torch.linalg.cholesky(H_inv, upper=True)

    # Group scales from original W (fixed; not recomputed after each column update)
    scales, zps = group_scales_zp(W.clone(), GROUP_SIZE)

    Q = torch.zeros_like(W)

    for blk in range(0, n_in, BLOCK_SIZE):
        blk_end = min(blk + BLOCK_SIZE, n_in)
        W_blk   = W[:, blk:blk_end].clone()            # [n_out, B]
        H_blk   = Hinv_U[blk:blk_end, blk:blk_end]    # [B, B]
        E_blk   = torch.zeros_like(W_blk)

        for k in range(blk_end - blk):
            col = blk + k
            g   = col // GROUP_SIZE
            w_q = quant_dequant(W_blk[:, k], scales[g], zps[g])

            Q[:, col]   = w_q
            err         = (W_blk[:, k] - w_q) / H_blk[k, k]
            E_blk[:, k] = err

            # Update remaining columns within this block
            W_blk[:, k + 1:] -= err.unsqueeze(1) * H_blk[k, k + 1:].unsqueeze(0)

        # Cross-block update: correct all columns to the right
        if blk_end < n_in:
            W[:, blk_end:] -= E_blk @ Hinv_U[blk:blk_end, blk_end:]

    return Q


# ── INT16 activation fake quant ─────────────────────────────────────────────

def a16_fake_quant(x: torch.Tensor) -> torch.Tensor:
    """Per-tensor symmetric INT16 fake quantization for activations."""
    scale = x.abs().max().clamp(min=1e-8) / 32767.0
    q = (x / scale).round().clamp(-32768, 32767)
    return q * scale


def apply_a16_hooks(model) -> list:
    """Register INT16 activation fake-quant pre-hooks on all eligible Linear layers."""
    handles = []
    for mod in model.modules():
        if isinstance(mod, torch.nn.Linear) and mod.weight.shape[0] != VOCAB_SIZE:
            def _pre(_m, inp):
                return (a16_fake_quant(inp[0]),) + inp[1:]
            handles.append(mod.register_forward_pre_hook(_pre))
    return handles


# ── Hessian collection ──────────────────────────────────────────────────────

class _HessAccum:
    """Online Hessian accumulator H = 2·X^T·X for one Linear (stored on CPU)."""
    __slots__ = ("H", "n")

    def __init__(self, n_in: int) -> None:
        self.H = torch.zeros(n_in, n_in)
        self.n = 0

    def update(self, x: torch.Tensor) -> None:
        x = x.detach().float().reshape(-1, x.shape[-1])
        self.H += (2.0 * x.T @ x).cpu()
        self.n += x.shape[0]


def collect_and_apply_gptq(model, calib_data: list) -> dict:
    """One forward pass to collect Hessians, then apply GPTQ in-place.
    Returns per-layer weight error metrics: {name: {cos, mse, snr_db, rel_err}}."""
    accums: dict = {}
    hooks  = []

    for name, mod in model.named_modules():
        if not isinstance(mod, torch.nn.Linear):
            continue
        if mod.weight.shape[0] == VOCAB_SIZE:
            continue
        acc = _HessAccum(mod.weight.shape[1])
        accums[name] = acc

        def _hook(_m, inp, _out, _acc=acc):
            _acc.update(inp[0])

        hooks.append(mod.register_forward_hook(_hook))

    device = next(model.parameters()).device
    print(f"  Calibration pass ({len(calib_data)} samples) ...", flush=True)
    with torch.inference_mode():
        for i, sample in enumerate(calib_data):
            if (i + 1) % 128 == 0:
                print(f"    {i + 1}/{len(calib_data)}", flush=True)
            model(sample["input_ids"].to(device))

    for h in hooks:
        h.remove()

    print(f"  Applying GPTQ to {len(accums)} layers ...", flush=True)
    layer_metrics = {}
    for name, mod in model.named_modules():
        if name not in accums:
            continue
        acc = accums[name]
        W_orig = mod.weight.data.clone().float()
        W_q = gptq_quantize(W_orig, acc.H)

        # Per-layer weight error metrics
        with torch.no_grad():
            w_f = W_orig.reshape(-1)
            w_q = W_q.reshape(-1).to(W_orig.device)
            cos = torch.nn.functional.cosine_similarity(w_f.unsqueeze(0), w_q.unsqueeze(0)).item()
            mse = ((w_f - w_q) ** 2).mean().item()
            sig_power = (w_f ** 2).mean().item()
            snr_db = 10 * torch.log10(torch.tensor(sig_power / (mse + 1e-12))).item()
            rel_err = ((w_f - w_q).abs().mean() / w_f.abs().mean().clamp(min=1e-8)).item()
        layer_metrics[name] = {"cos": cos, "mse": mse, "snr_db": snr_db, "rel_err": rel_err}

        mod.weight.data = W_q.to(mod.weight.dtype)
        del acc.H

    return layer_metrics


def print_layer_analysis(layer_metrics: dict) -> None:
    """Print per-layer quantization error table sorted by cos similarity (worst first)."""
    rows = sorted(layer_metrics.items(), key=lambda x: x[1]["cos"])
    print("\n" + "=" * 90)
    print(f"  {'Layer':<55}  {'Cos':>7}  {'MSE':>10}  {'SNR(dB)':>8}  {'RelErr':>8}")
    print("=" * 90)
    for name, m in rows:
        short = name.replace("model.layers.", "L").replace(".self_attn", ".attn").replace(".mlp", ".mlp")
        print(f"  {short:<55}  {m['cos']:>7.5f}  {m['mse']:>10.6f}  {m['snr_db']:>8.2f}  {m['rel_err']:>8.5f}")
    worst5 = rows[:5]
    print("=" * 90)
    print("  Worst 5 layers (by cos):")
    for name, m in worst5:
        print(f"    {name}  cos={m['cos']:.5f}  snr={m['snr_db']:.2f}dB")
    print("=" * 90 + "\n")


# ── Data ────────────────────────────────────────────────────────────────────

def load_calib_data(tokenizer, n: int) -> list:
    data = []
    with open(CALIB_FILE) as f:
        for line in f:
            text = json.loads(line)["text"]
            if len(text) < 50:
                continue
            enc = tokenizer(text, return_tensors="pt",
                            truncation=True, max_length=512)
            data.append({"input_ids": enc["input_ids"]})
            if len(data) >= n:
                break
    return data


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    print(f"Loading tokenizer and float32 model from {MODEL_PATH} ...", flush=True)
    tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
    model_f = AutoModelForCausalLM.from_pretrained(
        MODEL_PATH, dtype=torch.float32, device_map="auto"
    ).eval()

    prompts = load_eval_prompts(N_EVAL)
    print("Computing float baseline logits ...", flush=True)
    float_logits = collect_logits(model_f, tokenizer, prompts)
    del model_f
    torch.cuda.empty_cache()

    # ── Gate 1 ──────────────────────────────────────────────────────────────
    print(f"\n[Gate 1] Loading model for GPTQ, {N_CALIB} calib samples ...", flush=True)
    model_q = AutoModelForCausalLM.from_pretrained(
        MODEL_PATH, dtype=torch.float32, device_map="auto"
    ).eval()
    calib_data = load_calib_data(tokenizer, N_CALIB)
    print(f"  Loaded {len(calib_data)} samples.", flush=True)

    print("[Gate 1] Applying GPTQ W4 (from scratch) ...", flush=True)
    layer_metrics = collect_and_apply_gptq(model_q, calib_data)

    print("[Gate 1] Computing fake-quant logits ...", flush=True)
    quant_logits = collect_logits(model_q, tokenizer, prompts)

    metrics = compute_metrics(float_logits, quant_logits)
    passed  = print_results(metrics, label="GPTQ W4 Fake Quant — Gate 1")

    print_layer_analysis(layer_metrics)

    if not passed:
        del model_q
        torch.cuda.empty_cache()
        print("\n→ Gate 1 FAILED. Gate 2 skipped. Run analyze_layers.py for diagnosis.")
        sys.exit(1)

    print("\n→ Gate 1 PASSED. Proceeding to Gate 2: W4A16 actual quantization.",
          flush=True)

    # ── Gate 2: W4A16 ───────────────────────────────────────────────────────
    print("\n[Gate 2] Adding INT16 activation fake quantization ...", flush=True)
    handles = apply_a16_hooks(model_q)

    print("[Gate 2] Computing W4A16 fake-quant logits ...", flush=True)
    quant_logits_g2 = collect_logits(model_q, tokenizer, prompts)
    for h in handles:
        h.remove()
    del model_q
    torch.cuda.empty_cache()

    metrics_g2 = compute_metrics(float_logits, quant_logits_g2)
    passed_g2  = print_results(metrics_g2, label="GPTQ W4A16 Fake Quant — Gate 2")

    if passed_g2:
        print("\n→ Gate 2 PASSED. W4A16 GPTQ quantization validated.")
    else:
        print("\n→ Gate 2 FAILED.")
    sys.exit(0 if passed_g2 else 1)


if __name__ == "__main__":
    main()
