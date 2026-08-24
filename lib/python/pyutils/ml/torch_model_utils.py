import logging
import numpy as np
import os

import torch
import torch.nn as nn
import torch.nn.functional as F

from typing import Union

def write_str_line(fd, content: str):
    fd.write(content + os.linesep)

def save_named_modules(model: torch.nn.Module, path="torch_named_modules.txt"):
    # torch model 结构保存到文件
    with open(path, "w", encoding="utf-8") as f:
        for name, module in model.named_modules():
            f.write(f"{name}: {module}\n")

def load_checkpoint(model: torch.nn.Module, path: str):
    if torch.cuda.is_available():
        logging.info('Checkpoint: loading from checkpoint %s for GPU' % path)
        checkpoint = torch.load(path)
    else:
        logging.info('Checkpoint: loading from checkpoint %s for CPU' % path)
        checkpoint = torch.load(path, map_location='cpu')

    model.load_state_dict(checkpoint)

    with open("torch_model_param.txt", "w", encoding="utf-8") as tf:
        for name, param in model.named_parameters():
            if param.requires_grad:
                write_str_line(tf, f"Layer name: {name}")

                # param.shape 形状
                write_str_line(tf, f"Shape: {param.shape}")

                # 注意：需要区分多维张量(Weight)和一维张量(Bias)
                if param.dim() > 1:
                    # 对于多维张量，第一行/第一个Filter的前5个数据, param.data[0][:5]
                    preview = param.data[0][:5]
                    write_str_line(tf, f"Values (First dim, first 5): {param.data[0][:5]}")
                else:
                    # 对于一维张量（如 Bias），直接切片打印前5个
                    preview = param.data[:5]
                    write_str_line(tf, f"Values (First 5): {preview}")

            write_str_line(tf, "-" * 50)

def collect_tensor_shapes(obj, prefix=""):
    results = []

    if torch.is_tensor(obj):
        results.append({
            "path": prefix or "root",
            "shape": tuple(obj.shape),
            "dtype": obj.dtype,
            "device": str(obj.device)
        })

    elif isinstance(obj, dict):
        for k, v in obj.items():
            results.extend(
                collect_tensor_shapes(v, f"{prefix}.{k}" if prefix else str(k))
            )

    elif isinstance(obj, (list, tuple)):
        for i, v in enumerate(obj):
            results.extend(
                collect_tensor_shapes(v, f"{prefix}[{i}]")
            )

    elif hasattr(obj, "__dict__"):
        for k, v in vars(obj).items():
            results.extend(
                collect_tensor_shapes(v, f"{prefix}.{k}" if prefix else k)
            )

    return results

def save_tensor_to_bin(tensor, index):
    """
    方法       作用
    .cpu()     将数据从 GPU 显存复制到 CPU 内存
    .detach()  切断与计算图的连接，去除梯度追踪
    .numpy()   转换为 NumPy 数组
    .astype(np.float32)    强制转换为 32 位浮点
    """
    tensor_np = tensor.cpu().detach().numpy().astype(np.float32)

    # tofile 方法会将多维数组展平为 1D 字节流写入
    tensor_np.tofile(f"tensor_{index}.bin")
    print(f"saving tensor to tensor_{index}.bin")


def read_tensor_from_bin(bin_file, shape):
    """
    shape = (1, 3, 224, 224), 必须知道原来的形状和类型！
    """
    data = np.fromfile(bin_file, dtype=np.float32)
    tensor = data.reshape(shape)

    return tensor


def save_tensor_to_txt(
    tensor_or_pt: Union[str, torch.Tensor],
    txt_path: str,
    fmt: str = "%.6f",
    chunk_rows: int = 1000,
    keep_first_dim: bool = False,
    write_header: bool = True
):
    """
    将 torch.Tensor 或 .pt 文件中的 Tensor 保存为 txt 文件

    参数说明：
    - tensor_or_pt : torch.Tensor 或 .pt 文件路径
    - txt_path     : 输出 txt 路径
    - fmt          : 数值格式，如 %.6f / %.8e
    - chunk_rows   : 分块写入的行数，防止大 tensor OOM
    - keep_first_dim : True -> (N, -1)，False -> 全部 flatten
    - write_header : 是否写 shape / dtype / device 信息
    """

    # ---------- 1. 加载 tensor ----------
    if isinstance(tensor_or_pt, str):
        tensor = torch.load(tensor_or_pt, map_location="cpu")
        if not torch.is_tensor(tensor):
            raise TypeError(f"{tensor_or_pt} 中的对象不是 torch.Tensor")
    elif torch.is_tensor(tensor_or_pt):
        tensor = tensor_or_pt.detach().cpu()
    else:
        raise TypeError("输入必须是 torch.Tensor 或 .pt 文件路径")

    # ---------- 2. 记录原始信息 ----------
    original_shape = tuple(tensor.shape)
    numel = tensor.numel()
    dtype = tensor.dtype
    device = tensor.device
    ndim = tensor.ndim

    # ---------- 3. reshape ----------
    if ndim == 0:
        matrix = tensor.view(1, 1)
    elif ndim == 1:
        matrix = tensor.view(-1, 1)
    elif ndim == 2:
        matrix = tensor
    else:
        if keep_first_dim:
            matrix = tensor.view(tensor.shape[0], -1)
        else:
            matrix = tensor.flatten().view(1, -1)

    array = matrix.numpy()

    # ---------- 4. 写入 txt ----------
    with open(txt_path, "w") as f:
        if write_header:
            f.write(f"# original_shape:{original_shape}, reshaped_shape:{array.shape}, dtype:{dtype}, numel:{numel}, format:{fmt}, device:{device}\n")

        # 分块写入
        total_rows = array.shape[0]
        for start in range(0, total_rows, chunk_rows):
            end = min(start + chunk_rows, total_rows)
            np.savetxt(
                f,
                array[start:end],
                fmt=fmt
            )


def load_saved_pt_tensor(pt_file, map_location="cpu"):
    pt_obj = torch.load(pt_file, map_location)

    tensor_info = collect_tensor_shapes(pt_obj)
    print(tensor_info)

    return pt_obj


def export_model_raw_bin(model):
    buffers = []

    # 确保：
    # - 不参与计算图
    # - 在 CPU
    # - 连续内存
    # - dtype 固定
    for name, param in model.state_dict().items():
        if name.endswith("num_batches_tracked"):
            print(f"skip {name}")
            continue

        print(f"export layer:{name}")
        arr = (param.detach().cpu().contiguous().numpy().astype(np.float32))

        buffers.append(arr.reshape(-1))

    # 拼接 + 写入raw bin
    all_weights = np.concatenate(buffers, axis=0)

    with open("model_weights.bin", "wb") as f:
        f.write(all_weights.tobytes())

    print(f"✅ 导出完成，总 float32 数量: {all_weights.size}")
    print(f"✅ 文件大小: {all_weights.nbytes / 1024 / 1024:.2f} MB")


class LayerOutputSaver:
    def __init__(self, model, save_dir="layer_outputs", save_format="pt",
            skip_container=True):
        """
        save_format "pt" or "npy" or "txt"
        skip_container True 跳过 Sequential / ModuleList 等容器
        """
        self.model = model
        self.save_dir = save_dir
        self.save_format = save_format
        self.skip_container = skip_container

        self.handles = []
        self.inputs = {}
        self.outputs = {}

        os.makedirs(save_dir, exist_ok=True)

        self.register()

    def _is_container(self, module):
        return isinstance(
            module,
            (torch.nn.Sequential,
             torch.nn.ModuleList,
             torch.nn.ModuleDict)
        )

    def _hook(self, name):
        def fn(module, inputs, output):
            if torch.is_tensor(inputs[0]):
                input_data = inputs[0].detach().cpu()
                self.inputs[name + "_in"] = input_data

            if torch.is_tensor(output):
                out = output.detach().cpu()
                self.outputs[name] = out
                self.outputs[name + "_out"] = out
        return fn

    def register(self):
        """注册所有 forward hook"""
        for name, module in self.model.named_modules():
            if name == "":
                continue
            if self.skip_container and self._is_container(module):
                continue

            handle = module.register_forward_hook(self._hook(name))
            self.handles.append(handle)
            print(f"register_forward_hook {name}")

    def clear(self):
        """清空本次 forward 的缓存"""
        self.outputs = {}

    def remove(self):
        """移除所有 hook"""
        for h in self.handles:
            h.remove()
        self.handles = []

    def save(self, batch_idx=None):
        """保存所有中间层输出"""
        prefix = f"batch_{batch_idx}_" if batch_idx is not None else ""
        
        for name, input_data in self.inputs.items():
            safe_name = name.replace(".", "_")
            path = os.path.join(self.save_dir,
                    f"{prefix}{safe_name}.{self.save_format}")

            if self.save_format == "pt":
                torch.save(input_data, path)
            elif self.save_format == "npy":
                np.save(path, input_data.numpy())
            else: # txt
                save_tensor_to_txt(input_data, path)

        for name, out in self.outputs.items():
            safe_name = name.replace(".", "_")
            path = os.path.join(self.save_dir,
                    f"{prefix}{safe_name}.{self.save_format}")

            if self.save_format == "pt":
                torch.save(out, path)
            elif self.save_format == "npy":
                np.save(path, out.numpy())
            else: # txt
                save_tensor_to_txt(out, path)

            print(f"saving {path} done")
