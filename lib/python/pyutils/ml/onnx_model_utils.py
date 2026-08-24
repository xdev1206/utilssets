import os
import torch
import torch.nn as nn
import onnx
import onnxsim
import numpy as np
import onnxruntime as ort


ONNX_DTYPE_MAP = {
    "tensor(float)": np.float32,
    "tensor(float16)": np.float16,
    "tensor(int64)": np.int64,
    "tensor(int32)": np.int32,
    "tensor(int8)": np.int8,
    "tensor(uint8)": np.uint8,
    "tensor(bool)": np.bool_,
}


def extract_model_layers(model: nn.Module, sample_input: torch.Tensor):
    """提取模型每层的名字、类型、输入、输出信息"""
    layers_info = []

    def hook_fn(name, module_type):
        def hook(module, input, output):
            # 处理输入shape
            if isinstance(input, tuple):
                input_shape = [tuple(i.shape) if isinstance(i, torch.Tensor) else None for i in input]
            else:
                input_shape = [tuple(input.shape)] if isinstance(input, torch.Tensor) else None

            # 处理输出shape
            if isinstance(output, torch.Tensor):
                output_shape = tuple(output.shape)
            elif isinstance(output, tuple):
                output_shape = [tuple(o.shape) if isinstance(o, torch.Tensor) else None for o in output]
            else:
                output_shape = None

            info = {
                "name": name,
                "type": module_type,
                "input_shape": input_shape,
                "output_shape": output_shape
            }
            layers_info.append(info)
        return hook

    hooks = []
    for name, module in model.named_modules():
        if name:  # 跳过根模块
            hooks.append(module.register_forward_hook(hook_fn(name, module.__class__.__name__)))

    model.eval()
    with torch.no_grad():
        model(sample_input)

    for hook in hooks:
        hook.remove()

    return layers_info


def save_model_info(layers_info: list, save_path: str = "model_info.txt"):
    """保存模型层信息到文件"""
    lines = ["=== Model Layers Info ===\n"]

    for info in layers_info:
        lines.append(f"Name: {info['name']}")
        lines.append(f"  Type: {info['type']}")
        lines.append(f"  Input: {info['input_shape']}")
        lines.append(f"  Output: {info['output_shape']}")
        lines.append("")

    with open(save_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"模型信息已保存到: {save_path}")


def to_numpy(x):
    """转换为numpy数组"""
    if isinstance(x, np.ndarray):
        return x
    if isinstance(x, torch.Tensor):
        return x.detach().cpu().numpy()
    if isinstance(x, (int, float, bool, list, tuple)):
        return np.array(x)
    raise TypeError(f"无法转换类型: {type(x)}")


def torch_to_onnx(model: nn.Module, sample_input: torch.Tensor, onnx_path: str = "model.onnx",
                  input_names: list = None, output_names: list = None, opset_version: int = 18):
    """PyTorch模型转ONNX"""
    if input_names is None:
        input_names = ["input"]
    if output_names is None:
        output_names = ["output"]

    model.eval()
    torch.onnx.export(
        model, sample_input, onnx_path,
        input_names=input_names, output_names=output_names,
        opset_version=opset_version, external_data=False, export_params=False
    )
    print(f"ONNX模型已导出: {onnx_path}")


def simplify_onnx(onnx_path: str, output_path: str = None):
    """简化ONNX模型"""
    if output_path is None:
        output_path = onnx_path.replace(".onnx", "_simplified.onnx")

    model = onnx.load(onnx_path)
    model_simplified, check = onnxsim.simplify(model)

    if not check:
        print("警告: 模型简化检查失败")
        return None

    onnx.save(model_simplified, output_path)
    print(f"简化模型已保存: {output_path}")
    return output_path


def compare_outputs(torch_out: torch.Tensor, onnx_out: np.ndarray, name: str = "output"):
    """对比PyTorch和ONNX输出"""
    torch_np = to_numpy(torch_out)

    max_diff = np.max(np.abs(torch_np - onnx_out))
    mean_diff = np.mean(np.abs(torch_np - onnx_out))

    print(f"[{name}]")
    print(f"  shape: torch={torch_np.shape}, onnx={onnx_out.shape}")
    print(f"  max_diff={max_diff:.6e}, mean_diff={mean_diff:.6e}")
    print(f"  torch: mean={torch_np.mean():.6f}, std={torch_np.std():.6f}")
    print(f"  onnx:  mean={onnx_out.mean():.6f}, std={onnx_out.std():.6f}")
    print("-" * 50)

    return max_diff, mean_diff


def run_onnx_inference(onnx_path: str, inputs: dict, output_names: list = None):
    """运行ONNX推理"""
    sess = ort.InferenceSession(onnx_path, providers=["CPUExecutionProvider"])

    # 验证输入
    model_inputs = {inp.name: inp for inp in sess.get_inputs()}
    for name, value in inputs.items():
        if name not in model_inputs:
            raise ValueError(f"输入名称不匹配: {name}")
        inputs[name] = to_numpy(value)

    # 推理
    if output_names is None:
        output_names = [o.name for o in sess.get_outputs()]

    outputs = sess.run(output_names, inputs)
    return {name: val for name, val in zip(output_names, outputs)}


def convert_and_validate(model: nn.Module, sample_input: torch.Tensor, onnx_path: str = "model.onnx",
                        input_names: list = None, output_names: list = None,
                        opset_version: int = 18, simplify: bool = True, save_info: bool = False):
    """
    完整的模型转换和验证流程

    Args:
        model: PyTorch模型
        sample_input: 示例输入
        onnx_path: ONNX保存路径
        input_names: 输入名称列表，默认自动生成
        output_names: 输出名称列表，默认自动生成
        opset_version: ONNX opset版本
        simplify: 是否简化模型
        save_info: 是否保存模型信息到文件

    Returns:
        dict: 包含layers_info, onnx_path, max_diff, mean_diff等信息
    """
    model.eval()

    # 1. 提取模型层信息（始终保存到内存）
    layers_info = extract_model_layers(model, sample_input)

    # 2. 自动生成input/output names
    if input_names is None:
        input_names = [layers_info[0]['name']] if layers_info else ["input"]
    if output_names is None:
        output_names = [layers_info[-1]['name']] if layers_info else ["output"]

    # 3. 保存模型信息到文件（可选）
    if save_info:
        save_model_info(layers_info)

    # 4. 获取PyTorch输出
    with torch.no_grad():
        torch_output = model(sample_input)

    # 5. 转换为ONNX
    torch_to_onnx(model, sample_input, onnx_path, input_names, output_names, opset_version)

    # 6. 简化ONNX（可选）
    final_onnx_path = onnx_path
    if simplify:
        simplified_path = simplify_onnx(onnx_path)
        if simplified_path:
            final_onnx_path = simplified_path

    # 7. ONNX推理
    onnx_inputs = {input_names[0]: to_numpy(sample_input)}
    onnx_outputs = run_onnx_inference(final_onnx_path, onnx_inputs, output_names)

    # 8. 对比结果
    onnx_output = onnx_outputs[output_names[0]]
    max_diff, mean_diff = compare_outputs(torch_output, onnx_output)

    return {
        "layers_info": layers_info,
        "onnx_path": final_onnx_path,
        "max_diff": max_diff,
        "mean_diff": mean_diff,
        "torch_output": torch_output,
        "onnx_output": onnx_output
    }
