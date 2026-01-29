import os
import torch
import torch.nn as nn
import torchvision.models as models
import onnx
import onnxsim
import numpy as np
import onnxruntime as ort


def print_and_save_model_info(model: nn.Module, sample_tensor: torch.Tensor,
                              file_path: str = "model_info.txt"):
    """
    打印并保存模型树结构，同时获取输入层和输出层名字

    参数：
        model: nn.Module 模型
        sample_tensor: 用来跑一次前向传播的张量（确定实际输入/输出层）
        file_path: 保存文件路径
    """
    lines = []
    input_layer_name = None
    output_layer_name = None

    # 获取实际运行时的输入/输出层名字
    def hook_input(module, input, output):
        nonlocal input_layer_name
        if input_layer_name is None:  # 第一次记录
            input_layer_name = module.__class__.__name__

    def hook_output(module, input, output):
        nonlocal output_layer_name
        output_layer_name = module.__class__.__name__

    # 找第一层模块（跳过 model 本身）
    first_child = list(model.named_modules())[1][1]
    last_child = list(model.named_modules())[-1][1]
    first_child.register_forward_hook(hook_input)
    last_child.register_forward_hook(hook_output)

    # 跑一次前向传播
    _ = model(sample_tensor)

    # 内部递归构建树
    def _build_tree(mod: nn.Module, prefix: str = ""):
        children = list(mod.named_children())
        child_count = len(children)
        for i, (name, child) in enumerate(children):
            connector = "└── " if i == child_count - 1 else "├── "
            line = prefix + connector + f"{name} ({child.__class__.__name__})"
            print(line)           # 屏幕打印
            lines.append(line)    # 存到列表
            next_prefix = prefix + ("    " if i == child_count - 1 else "│   ")
            _build_tree(child, next_prefix)

    # 构建树结构
    _build_tree(model)

    # 在顶部插入输入/输出层信息
    header = [
        f"输入层: {input_layer_name}",
        f"输出层: {output_layer_name}",
        "-"*40
    ]
    lines = header + lines

    # 保存到文件
    with open(file_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    # torch model 直接保存到文件
    with open("torch_name_modules.txt", "w", encoding="utf-8") as tf:
        for name, module in model.named_modules():
            tf.write(f"{name}: {module}\n")

    print(f"\n模型结构已保存到: {file_path}")
    print(f"输入层: {input_layer_name}")
    print(f"输出层: {output_layer_name}")
    print(input_layer_name, output_layer_name)

    return input_layer_name, output_layer_name


def export_optimize_validate(model: nn.Module, sample_tensor: torch.Tensor,
                             onnx_path: str = "model.onnx",
                             opset_version: int = 13,
                             input_names = ["input"],
                             output_names = ["output"]):
    """
    将 PyTorch 模型导出为 ONNX，使用 onnxsim 优化，并验证精度
    """
    model.eval()

    # 导出为 ONNX
    torch.onnx.export(
        model,
        sample_tensor,
        onnx_path,
        input_names=input_names,
        output_names=output_names,
        opset_version=opset_version,
        external_data=False
    )
    print(f"已导出 ONNX 模型到 {onnx_path}")

    # 加载优化
    onnx_model = onnx.load(onnx_path)
    model_simplified, check = onnxsim.simplify(
        onnx_model,
        test_input_shapes={input_names[0]: list(sample_tensor.shape)}  # 明确shape更稳定
    )
    if not check:
        print("模型简化检查失败")
        return

    onnx_simplified_path = "simplified_" + onnx_path
    onnx.save(model_simplified, onnx_simplified_path)
    print(f"已优化 ONNX 模型并保存到 {onnx_simplified_path}")

    # 验证精度
    # 原始ONNX推理
    ort_session_original = ort.InferenceSession(onnx_path)
    output_original = ort_session_original.run(output_names, {input_names[0]: sample_tensor.numpy()})[0]

    # 简化ONNX推理
    ort_session_simplified = ort.InferenceSession(onnx_simplified_path)
    output_simplified = ort_session_simplified.run(output_names, {input_names[0]: sample_tensor.numpy()})[0]

    # 计算误差
    diff = np.abs(output_original - output_simplified)
    max_diff = diff.max()
    mean_diff = diff.mean()
    print(f"精度验证：max_diff={max_diff:.6f}, mean_diff={mean_diff:.6f}")

    if max_diff < 1e-5:
        print("精度一致（优化未影响输出）")
    else:
        print("优化后输出有差异，请检查模型结构/输入")


def convert_model(model: nn.Module,
                  input_tensor: torch.Tensor,
                  onnx_path: str = "model.onnx",
                  opset_version: int = 18,
                  input_names = ["input"],
                  output_names = ["output"]):

    input_layer_name, output_layer_name = print_and_save_model_info(model, input_tensor)
    print(f"input layer: {input_layer_name}, output_layer: {output_layer_name}")

    if input_layer_name is not None and output_layer_name is not None:
        export_optimize_validate(model, input_tensor,
                onnx_path=onnx_path, opset_version=opset_version,
                input_names=[input_layer_name], output_names=[output_layer_name])
    else:
        print("error: ", input_layer_name, output_layer_name)


ONNX_DTYPE_MAP = {
    "tensor(float)": np.float32,
    "tensor(float16)": np.float16,
    "tensor(int64)": np.int64,
    "tensor(int32)": np.int32,
    "tensor(int8)": np.int8,
    "tensor(uint8)": np.uint8,
    "tensor(bool)": np.bool_,
}

def save_onnx_output_to_txt(name: str, output_array: np.ndarray):
    # 展平成一维，方便保存
    reshaped_array = output_array.reshape(-1)

    dtype = reshaped_array.dtype
    numel = reshaped_array.size

    with open(name + ".txt", "w", encoding="utf-8") as f:
        # 写入头信息
        f.write(
            f"# name:{name} "
            f"original_shape:{output_array.shape}, "
            f"reshaped_shape:{reshaped_array.shape}, "
            f"dtype:{dtype}, "
            f"numel:{numel}\n"
        )

        # 写入数据，保留 6 位小数
        formatted_data = ", ".join(
            f"{x:.6f}" for x in reshaped_array
        )
        f.write(formatted_data + "\n")


def to_numpy(x):
    """
    自动将常见 tensor 类型转换为 numpy.ndarray
    """
    # 1. 已经是 numpy
    if isinstance(x, np.ndarray):
        return x

    # 2. PyTorch Tensor
    try:
        if isinstance(x, torch.Tensor):
            if x.is_cuda:
                x = x.detach().cpu()
            return x.detach().numpy()
    except ImportError:
        pass

    # 3. Python 标量
    if isinstance(x, (int, float, bool)):
        return np.array(x)

    # 4. list / tuple
    if isinstance(x, (list, tuple)):
        return np.array(x)

    raise TypeError(f"❌ 无法将类型 {type(x)} 转换为 numpy.ndarray")


# key = onnx input name（必须一致）
# user_inputs = {
#     "speech": np.ndarray,          # float32 [B, T, 80]
#     "speech_lengths": np.ndarray   # int64   [B]
# }
def validate_and_build_inputs(sess, user_inputs: dict):
    inputs = {}
    model_inputs = sess.get_inputs()

    model_input_names = {i.name for i in model_inputs}
    user_input_names = set(user_inputs.keys())

    missing = model_input_names - user_input_names
    extra = user_input_names - model_input_names
    if missing:
        raise ValueError(f"❌ 缺少模型输入: {missing}")
    if extra:
        raise ValueError(f"❌ 多余输入: {extra}")

    for inp in model_inputs:
        name = inp.name
        expected_shape = inp.shape
        expected_type = inp.type
        print(f"  onnx input name={inp.name}, shape={inp.shape}, type={inp.type}")

        value = to_numpy(user_inputs[name])  # ✅ 自动转换

        expected_np_dtype = ONNX_DTYPE_MAP[expected_type]
        if value.dtype != expected_np_dtype:
            raise TypeError(f"❌ 输入 `{name}` dtype 不匹配: 期望 {expected_np_dtype}, 实际 {value.dtype}")

        if len(value.shape) != len(expected_shape):
            raise ValueError(f"❌ 输入 `{name}` rank 不匹配")

        for i, (real, exp) in enumerate(zip(value.shape, expected_shape)):
            if exp is None or isinstance(exp, str):
                continue
            if real != exp:
                raise ValueError(f"❌ 输入 `{name}` 第 {i} 维不匹配: {real} vs {exp}")

        inputs[name] = value

    return inputs

def onnx_model_run(user_inputs, onnx_path="model.onnx", all_layer_output=False, keep=None,
        save_format="npz", save_path="model.onnx.output"):
    model = onnx.load(onnx_path)

    if all_layer_output:
        model.graph.output.clear()

        # 将每个 node 的输出都加入 graph.output
        for node in model.graph.node:
            for out in node.output:
                value_info = onnx.ValueInfoProto()
                value_info.name = out
                model.graph.output.append(value_info)

        onnx_path = "all_layer_ouput_" + onnx_path
        onnx.save(model, onnx_path)

    so = ort.SessionOptions()
    so.enable_profiling = True
    sess = ort.InferenceSession(onnx_path, so, providers=["CPUExecutionProvider"]) # 或 CUDAExecutionProvider
    inputs = validate_and_build_inputs(sess, user_inputs)

    if keep is None:
        output_names = [o.name for o in sess.get_outputs()]
    else:
        output_names = keep

    output_values = sess.run(output_names, inputs)

    profile_file = sess.end_profiling()
    print(profile_file)

    outputs = dict()
    for out, val in zip(sess.get_outputs(), output_values):
        outputs[out.name] = val
        save_onnx_output_to_txt(out.name, val)

    if save_format == "npz":
        # 推荐：一个文件保存所有输出
        np.savez(save_path, **outputs)

    elif save_format == "npy":
        # 每个 output 一个文件
        base, _ = os.path.splitext(save_path)
        for name, val in outputs.items():
            np.save(f"{base}_{name}.npy", val)

    else:
        raise ValueError(f"❌ 不支持的保存格式: {save_format}")

    return outputs, output_values

def compare(torch_out, onnx_out, name):
    torch_np = torch_out.numpy()
    onnx_np = onnx_out

    print(f"[{name}]")
    print(" shape:", torch_np.shape, onnx_np.shape)
    print(" max abs diff:", np.max(np.abs(torch_np - onnx_np)))
    print(" mean abs diff:", np.mean(np.abs(torch_np - onnx_np)))
    print(" torch mean/std:", torch_np.mean(), torch_np.std())
    print(" onnx  mean/std:", onnx_np.mean(), onnx_np.std())
    print("-" * 50)
