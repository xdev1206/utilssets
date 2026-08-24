#!usr/bin/python
# encoding=utf-8

import argparse

def exec_rpc(magnet):
    """
    使用 rpc，减少线程资源占用，关于这部分的详细信息科参考
    https://aria2.github.io/manual/en/html/aria2c.html?highlight=enable%20rpc#aria2.addUri
    """
    conn = HTTPConnection(ARIA2RPC_ADDR, ARIA2RPC_PORT)
    req = {
        "jsonrpc": "2.0",
        "id": "magnet",
        "method": "aria2.addUri",
        "params": [
            [magnet],
            {
                "bt-stop-timeout": str(STOP_TIMEOUT),
                "max-concurrent-downloads": str(MAX_CONCURRENT),
                "listen-port": "6881",
                "dir": SAVE_PATH,
            },
        ],
    }
    conn.request(
        "POST", "/jsonrpc", json.dumps(req), {"Content-Type": "application/json"}
    )

    res = json.loads(conn.getresponse().read())
    if "error" in res:
        print("Aria2c replied with an error:", res["error"])


if __name__  == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-mag')
    args = parser.parse_args()
    print(args.mag)
    exec_rpc(args.mag)
