#encoding=utf-8

import hashlib
import time


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
    nick_name = "ticsmts"
    
    nonce1, text1, h1, use_time1 = mine_test(nick_name, 4)
    print(f"耗时: {use_time1:.6f} 秒")
    print(f"Hash 内容: {text1}")
    print(f"Hash 值:   {h1}")
    print(f"nonce:     {nonce1}")
    print()

    nonce2, text2, h2, use_time2 = mine_test(nick_name, 5)
    print(f"耗时: {use_time2:.6f} 秒")
    print(f"Hash 内容: {text2}")
    print(f"Hash 值:   {h2}")
    print(f"nonce:     {nonce2}")
    print()



if __name__ == "__main__":
    run()