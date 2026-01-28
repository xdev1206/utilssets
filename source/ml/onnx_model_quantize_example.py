import argparse
import numpy as np
import onnxruntime
import time
from onnxruntime.quantization import QuantFormat, QuantType, quantize_static, CalibrationDataReader

import os
import sys

env_path = os.environ.get("ENV_PATH")
print("ENV_PATH repr:", repr(env_path))

env_path = os.path.expanduser(env_path.strip())
print("ENV_PATH normalized:", env_path)
print("ENV_PATH exists:", os.path.exists(env_path))

for base_path in env_path.split(os.pathsep):
    torch_path = os.path.join(env_path, "..", "source", "torch")
    torch_path = os.path.abspath(os.path.normpath(torch_path))

    print("torch_path:", torch_path)
    print("exists:", os.path.exists(torch_path))
    print("isdir:", os.path.isdir(torch_path))

    if os.path.exists(torch_path):
        print("listdir:", os.listdir(torch_path)[:5])

    if os.path.isdir(torch_path):
        if torch_path not in sys.path:
            print("add path", torch_path)
            sys.path.insert(0, torch_path)

import torch_model_utils
import onnx_model_utils


class DataReader(CalibrationDataReader):
    def __init__(self, dataset):
        """
        dataset: iterable
          每个元素是 dict:
        [
            {
                "input_name1": np.ndarray,
                "input_name2": np.ndarray,
                ...
            },
            ...
            {
                ...
            }
        ]
        """
        self.dataset = iter(dataset)

    def get_next(self):
        return next(self.dataset, None)


def benchmark(model_path, input_dict):
    """
    input_dict: {input_name: input_data}
    """

    session = onnxruntime.InferenceSession(model_path)

    total = 0.0
    runs = 10
    # Warming up
    _ = session.run([], input_dict)
    for i in range(runs):
        start = time.perf_counter()
        _ = session.run([], input_dict)
        end = (time.perf_counter() - start) * 1000
        total += end
        print(f"{end:.2f}ms")
    total /= runs
    print(f"Avg: {total:.2f}ms")


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_model", required=True, help="input model")
    parser.add_argument("--output_model", required=True, help="output model")
    #parser.add_argument("--calibrate_dataset", default="./test_images", help="calibration data set")
    parser.add_argument(
        "--quant_format",
        default=QuantFormat.QDQ,
        type=QuantFormat.from_string,
        choices=list(QuantFormat),
    )
    parser.add_argument("--per_channel", default=False, type=bool, help="True or False")
    args = parser.parse_args()
    return args


def load_tensor():

    dataset = list()
    for i in range(35):
        input_ = dict()
        bin_file = "tensor_" + str(i) + ".bin"
        shape = (1, 24, 80)
        tensor = torch_model_utils.read_tensor_from_bin(bin_file, shape)
        input_["GlobalCMVN"] = tensor

        dataset.append(input_)

    return dataset


def main():
    args = get_args()
    input_model_path = args.input_model
    output_model_path = args.output_model

    dataset = load_tensor()
    dr = DataReader(dataset)

    # Calibrate and quantize model
    # Turn off model optimization during quantization
    quantize_static(
        input_model_path,
        output_model_path,
        dr,
        quant_format=args.quant_format,
        per_channel=args.per_channel,
        weight_type=QuantType.QInt8,
    )
    print("Calibrated and quantized model saved.")

    print("benchmarking fp32 model...")
    benchmark(input_model_path, dataset[0])

    print("benchmarking int8 model...")
    benchmark(output_model_path, dataset[0])


if __name__ == "__main__":
    main()
