{
  "version": "1.2",
  "package": {
    "name": "",
    "version": "",
    "description": "",
    "author": "",
    "image": ""
  },
  "design": {
    "board": "go-board",
    "graph": {
      "blocks": [
        {
          "id": "6f6d3a29-336a-4b3c-bcbc-93a9e6fa8d07",
          "type": "basic.input",
          "data": {
            "name": "sw1",
            "virtual": false,
            "pins": [
              {
                "index": "0",
                "name": "SW1",
                "value": "53"
              }
            ],
            "clock": false
          },
          "position": {
            "x": 160,
            "y": 192
          }
        },
        {
          "id": "a63b36fb-c002-4755-8f15-068dc036d5e2",
          "type": "basic.output",
          "data": {
            "name": "D1",
            "virtual": false,
            "pins": [
              {
                "index": "0",
                "name": "LED1",
                "value": "56"
              }
            ]
          },
          "position": {
            "x": 368,
            "y": 192
          }
        },
        {
          "id": "0bbce6cf-5883-4441-98b0-96517bc3bc89",
          "type": "basic.input",
          "data": {
            "name": "sw1",
            "virtual": false,
            "pins": [
              {
                "index": "0",
                "name": "SW2",
                "value": "51"
              }
            ],
            "clock": false
          },
          "position": {
            "x": 160,
            "y": 288
          }
        },
        {
          "id": "aa5de262-f609-450a-a674-6e8daeb5bab3",
          "type": "basic.output",
          "data": {
            "name": "D1",
            "virtual": false,
            "pins": [
              {
                "index": "0",
                "name": "LED2",
                "value": "57"
              }
            ]
          },
          "position": {
            "x": 368,
            "y": 288
          }
        },
        {
          "id": "dc6f8395-62a9-4671-98f1-75a80c2e85dc",
          "type": "basic.input",
          "data": {
            "name": "sw1",
            "virtual": false,
            "pins": [
              {
                "index": "0",
                "name": "SW3",
                "value": "54"
              }
            ],
            "clock": false
          },
          "position": {
            "x": 160,
            "y": 384
          }
        },
        {
          "id": "193e42e9-d90b-4c39-bbd5-74ef40c96ad9",
          "type": "basic.output",
          "data": {
            "name": "D1",
            "virtual": false,
            "pins": [
              {
                "index": "0",
                "name": "LED3",
                "value": "59"
              }
            ]
          },
          "position": {
            "x": 368,
            "y": 384
          }
        },
        {
          "id": "a2a4dff4-cbab-4209-a931-dc8e54f62d54",
          "type": "basic.input",
          "data": {
            "name": "sw1",
            "virtual": false,
            "pins": [
              {
                "index": "0",
                "name": "SW4",
                "value": "52"
              }
            ],
            "clock": false
          },
          "position": {
            "x": 160,
            "y": 472
          }
        },
        {
          "id": "dde662c6-ae48-4177-8ec6-fd00341988d6",
          "type": "basic.output",
          "data": {
            "name": "D1",
            "virtual": false,
            "pins": [
              {
                "index": "0",
                "name": "LED4",
                "value": "60"
              }
            ]
          },
          "position": {
            "x": 368,
            "y": 472
          }
        }
      ],
      "wires": [
        {
          "source": {
            "block": "6f6d3a29-336a-4b3c-bcbc-93a9e6fa8d07",
            "port": "out"
          },
          "target": {
            "block": "a63b36fb-c002-4755-8f15-068dc036d5e2",
            "port": "in"
          }
        },
        {
          "source": {
            "block": "0bbce6cf-5883-4441-98b0-96517bc3bc89",
            "port": "out"
          },
          "target": {
            "block": "aa5de262-f609-450a-a674-6e8daeb5bab3",
            "port": "in"
          },
          "vertices": []
        },
        {
          "source": {
            "block": "dc6f8395-62a9-4671-98f1-75a80c2e85dc",
            "port": "out"
          },
          "target": {
            "block": "193e42e9-d90b-4c39-bbd5-74ef40c96ad9",
            "port": "in"
          },
          "vertices": []
        },
        {
          "source": {
            "block": "a2a4dff4-cbab-4209-a931-dc8e54f62d54",
            "port": "out"
          },
          "target": {
            "block": "dde662c6-ae48-4177-8ec6-fd00341988d6",
            "port": "in"
          },
          "vertices": []
        }
      ]
    }
  },
  "dependencies": {}
}