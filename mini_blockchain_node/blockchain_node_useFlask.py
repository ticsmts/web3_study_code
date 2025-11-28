#encoding=utf-8

'''
模拟实现最小的区块链， 包含两个功能：

1. POW 证明出块，难度为 4 个 0 开头
2. 每个区块包含previous_hash 让区块串联起来。
如下是一个参考区块结构：
block = {
    'index': 1,
    'timestamp': 1506057125,
    'transactions': [{
        'sender': "xxx",
        'recipient': "xxx",
        'amount': 5,
        }],
    'proof': 324984774000,
    'previous_hash': "xxxx"
}

通过Flask实现
'''


import hashlib
import json
import time
from urllib.parse import urlparse

import requests
from flask import Flask, jsonify, request, render_template
from uuid import uuid4

class Blockchain:
    def __init__(self):
        self.chain = []
        self.current_transactions = []
        # 已知节点的集合（host:port）
        self.nodes = set()
        # 创世区块
        self.new_block(previous_hash="1", proof=100)

    def new_block(self, proof, previous_hash=None):
        '''
        创建新区块
        :param proof:
        :param previous_hash:
        :return:
        '''

        block = {
            'index':len(self.chain)+1,
            'timestamp': time.time(),
            'transactions': self.current_transactions,
            'proof': proof,
            'previous_hash': previous_hash or self.hash(self.chain[-1])
        }

        self.current_transactions = []

        self.chain.append(block)
        return block


    def new_transaction(self, sender, recipient, amount):
        '''
        创建新交易
        :param sender: 发送者地址
        :param recipient: 接受者地址
        :param amount: 数量
        :return: 保存该交易的新区块的index
        '''
        self.current_transactions.append({
             'sender': sender,
             'recipient': recipient,
             'amount': amount
             })
        return self.last_block['index'] + 1

    @staticmethod
    def hash(block):
        '''
        静态方法，对区块进行hash
        :param block: 区块
        :return: 该区块的sha256 hash值
        '''
        block_string = json.dumps(block, sort_keys=True).encode()
        return hashlib.sha256(block_string).hexdigest()

    @property
    def last_block(self):
        return self.chain[-1]

    def register_node(self, address: str):
        """
        向节点列表中添加一个新节点
        :param address: 节点地址，例如 'http://127.0.0.1:5001'
        """
        parsed_url = urlparse(address)
        if parsed_url.netloc:
            # 例如 '127.0.0.1:5001'
            self.nodes.add(parsed_url.netloc)
        elif parsed_url.path:
            # 万一传的是 '127.0.0.1:5001' 没有协议
            self.nodes.add(parsed_url.path)
        else:
            raise ValueError("Invalid URL")

    def proof_of_work(self, last_proof):
        '''
        :param last_proof: 上一个区块的工作量证明
        :return: 区块的proof
        '''
        proof = 0
        while self.valid_proof(last_proof, proof) is False:
            proof += 1
        return proof

    @staticmethod
    def valid_proof(last_proof, proof):
        '''
        自定义POW: 寻找一个数 proof，使得它与前一个区块的 proof 拼接成的字符串的 Hash 值以 4 个零开头。
        :param last_proof: 前一个区块的proof值
        :param proof: 当前区块需要计算的工作量证明proof
        :return: 验证失败返回False，验证成功返回True
        '''
        text = f"{last_proof}{proof}"
        h = hashlib.sha256(text.encode("utf-8")).hexdigest()
        if (h.startswith("0000")):
            return True
        else:
            return False

    def valid_chain(self, chain: list) -> bool:
        """
        判断一条链是否有效：
        - 每个块的 previous_hash 是否等于前一个块的 hash
        - 每个块的 proof 是否满足我们的 POW 规则
        """
        if not chain:
            return False

        last_block = chain[0]
        current_index = 1

        while current_index < len(chain):
            block = chain[current_index]

            # 1. 检查 previous_hash 是否正确
            last_block_hash = self.hash(last_block)
            if block['previous_hash'] != last_block_hash:
                return False

            # 2. 检查 PoW 是否有效
            last_proof = last_block['proof']
            proof = block['proof']
            if not self.valid_proof(last_proof, proof):
                return False

            last_block = block
            current_index += 1

        return True

    def resolve_conflicts(self) -> bool:
        """
        共识算法：解决冲突
        - 向所有已知节点拉取链数据
        - 如果发现比自己的更长且合法的链，就用它替换自己当前的链
        :return: 如果链被替换了返回 True，否则 False
        """
        neighbours = self.nodes
        new_chain = None

        # 只寻找比当前更长的链
        max_length = len(self.chain)

        for node in neighbours:
            try:
                response = requests.get(f"http://{node}/chain", timeout=5)
            except requests.RequestException:
                # 某个节点挂了/连不上，直接跳过
                continue

            if response.status_code != 200:
                continue

            data = response.json()
            length = data.get('length')
            chain = data.get('chain')

            # 如果链更长且合法，就记录下来
            if length and length > max_length and self.valid_chain(chain):
                max_length = length
                new_chain = chain

        # 如果发现了更好的链，就替换当前的
        if new_chain:
            self.chain = new_chain
            return True

        return False


app = Flask(__name__)

# 给这个节点生成一个唯一地址（用于接收挖矿奖励）
node_identifier = str(uuid4()).replace('-', '')

# 实例化区块链
blockchain = Blockchain()

@app.route('/', methods=['GET'])
def index():
    return render_template('index.html')

@app.route('/mine', methods=['GET'])
def mine():
    '''
    挖出新区块
    :return:
    '''
    # 1. 获取上一个区块的proof
    last_block = blockchain.last_block
    last_proof = last_block['proof']

    # 2. 找到新区块的工作量证明
    proof = blockchain.proof_of_work(last_proof)

    # 3. 挖出新区块后，给矿工奖励
    blockchain.new_transaction(
        sender="0",
        recipient=node_identifier,
        amount=1,
    )

    # 4. 构造新区块
    block = blockchain.new_block(proof=proof)

    response = {
        'message': '新区块已挖出',
        'index': block['index'],
        'transactions': block['transactions'],
        'proof': block['proof'],
        'previous_hash': block['previous_hash'],
    }

    return jsonify(response), 200

@app.route('/transactions/new', methods=['POST'])
def new_transaction():
    '''
    发起一笔交易
    :return:
    '''
    values = request.get_json()

    required = ['sender', 'recipient', 'amount']
    if not values or not all(k in values for k in required):
        return jsonify({'error': '缺少必要字段'}), 400

    index = blockchain.new_transaction(
        values['sender'],
        values['recipient'],
        values['amount'],
    )

    response = {'message': f'交易将被添加到区块 {index} 中'}
    return jsonify(response), 201

@app.route('/chain', methods=['GET'])
def full_chain():
    '''
    返回完整区块链
    :return:
    '''
    response = {
        'chain': blockchain.chain,
        'length': len(blockchain.chain)
    }

    return jsonify(response), 200

@app.route('/nodes/register', methods=['POST'])
def register_nodes():
    """
    接收一个包含多个节点地址的列表，注册到当前节点
    请求体示例：
    {
      "nodes": [
        "http://127.0.0.1:5001",
        "http://127.0.0.1:5002"
      ]
    }
    """
    values = request.get_json()

    nodes = values.get('nodes') if values else None
    if nodes is None or not isinstance(nodes, list) or not nodes:
        return jsonify({'error': '请提供 nodes 字段，且为非空列表'}), 400

    for node in nodes:
        blockchain.register_node(node)

    response = {
        'message': '新节点已加入',
        'total_nodes': list(blockchain.nodes),
    }
    return jsonify(response), 201

@app.route('/nodes/resolve', methods=['GET'])
def consensus():
    """
    触发共识算法，与其他节点对比链长，必要时替换当前链
    """
    replaced = blockchain.resolve_conflicts()

    if replaced:
        response = {
            'message': '我们的链被替换为网络中的最长合法链',
            'new_chain': blockchain.chain,
        }
    else:
        response = {
            'message': '我们的链已经是最长合法链',
            'chain': blockchain.chain,
        }

    return jsonify(response), 200


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=5000)
    args = parser.parse_args()

    app.run(host='0.0.0.0', port=args.port, debug=True)






