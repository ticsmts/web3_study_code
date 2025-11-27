#encoding=utf-8

import hashlib
import time
import argparse 


def mine_test(nickname, zero_count):
    nonce = 0 
    prefix_zeros = zero_count * "0"
    start = time.perf_counter()

    while True:
        text = f"{nickname}{nonce}"
        h = hashlib.sha256(text.encode("utf-8")).hexdigest()
        if(h.startswith(prefix_zeros)):
            end = time.perf_counter()
            use_time = end - start
            return nonce, text, h, use_time
        nonce += 1


def run():
    parser = argparse.ArgumentParser(description="POW 命令行实现")
    parser.add_argument("--name", type=str, default="ticsmts", help="用于工作量证明的昵称")
    parser.add_argument("--zeros", type=int, default=4, help="哈希值的前置0数量")

    args = parser.parse_args()
    
    nonce1, text1, h1, use_time1 = mine_test(args.name, args.zeros)
    print(f"耗时: {use_time1:.6f} 秒")
    print(f"Hash 内容: {text1}")
    print(f"Hash 值:   {h1}")
    print(f"nonce:     {nonce1}")
    print()


if __name__ == "__main__":
    run()