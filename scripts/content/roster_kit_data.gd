extends RefCounted
## Numeric roster authority; runtime state belongs to scripts/battle.
const DATA := {
  "JIA": {
    "name": "贾苇索",
    "entry_level": 1,
    "base": {
      "hp": 220,
      "mp": 90,
      "attack": 27,
      "armor": 7,
      "speed": 1.45,
      "move": 215,
      "regen": 2.8
    },
    "basic": {
      "id": "JIA_basic",
      "title": "普攻",
      "kind": "SWEEP",
      "power": 1,
      "reach": 112,
      "cooldown": 0.6896551724137931,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "jia_sweep",
        "title": "横扫",
        "kind": "NOVA",
        "power": 2.5,
        "reach": 150,
        "cooldown": 5,
        "mana_cost": 22,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "jia_break",
        "title": "破阵",
        "kind": "THRUST",
        "power": 4.5,
        "reach": 245,
        "cooldown": 10,
        "mana_cost": 36,
        "unlock_level": 3,
        "mechanic": "expose",
        "params": {
          "duration": 4,
          "multiplier": 0.12
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {},
    "owned": {},
    "trait": "",
    "trait_params": {}
  },
  "M01": {
    "name": "吕布",
    "entry_level": 9,
    "base": {
      "hp": 255,
      "mp": 95,
      "attack": 38,
      "armor": 9,
      "speed": 1,
      "move": 210,
      "regen": 2.1
    },
    "basic": {
      "id": "M01_basic",
      "title": "普攻",
      "kind": "SWEEP",
      "power": 1,
      "reach": 155,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "M01_cleave",
        "title": "方天破军",
        "kind": "NOVA",
        "power": 5,
        "reach": 240,
        "cooldown": 13,
        "mana_cost": 46,
        "unlock_level": 1,
        "mechanic": "expose",
        "params": {
          "duration": 4,
          "multiplier": 0.16
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "M01_rally",
        "title": "鬼神降临",
        "kind": "WARD",
        "power": 0,
        "reach": 0,
        "cooldown": 20,
        "mana_cost": 48,
        "unlock_level": 9,
        "mechanic": "rally",
        "params": {
          "duration": 6,
          "attack_multiplier": 0.3,
          "speed_multiplier": 0.08
        },
        "target_scope": "self",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "M01_support",
      "title": "掠阵横戟",
      "kind": "SWEEP",
      "power": 2,
      "reach": 225,
      "cooldown": 8,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "attack": 0.3
    },
    "trait": "",
    "trait_params": {}
  },
  "M02": {
    "name": "张辽",
    "entry_level": 8,
    "base": {
      "hp": 210,
      "mp": 105,
      "attack": 30,
      "armor": 8,
      "speed": 1.35,
      "move": 230,
      "regen": 2.7
    },
    "basic": {
      "id": "M02_basic",
      "title": "普攻",
      "kind": "THRUST",
      "power": 1,
      "reach": 155,
      "cooldown": 0.7407407407407407,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "M02_dash",
        "title": "破阵突击",
        "kind": "THRUST",
        "power": 3.2,
        "reach": 230,
        "cooldown": 8,
        "mana_cost": 30,
        "unlock_level": 1,
        "mechanic": "dash",
        "params": {
          "distance": 150
        },
        "target_scope": "active",
        "slow": 0.6,
        "duration": 1.2,
        "magic": false
      },
      {
        "id": "M02_expose",
        "title": "斩将",
        "kind": "THRUST",
        "power": 4,
        "reach": 240,
        "cooldown": 11,
        "mana_cost": 38,
        "unlock_level": 8,
        "mechanic": "expose",
        "params": {
          "duration": 4,
          "multiplier": 0.15
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "M02_support",
      "title": "追锋",
      "kind": "THRUST",
      "power": 1.5,
      "reach": 240,
      "cooldown": 5,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0.4,
      "duration": 1.2,
      "magic": false
    },
    "owned": {
      "move": 0.3
    },
    "trait": "",
    "trait_params": {}
  },
  "M03": {
    "name": "高顺",
    "entry_level": 8,
    "base": {
      "hp": 275,
      "mp": 115,
      "attack": 22,
      "armor": 17,
      "speed": 1,
      "move": 185,
      "regen": 2.8
    },
    "basic": {
      "id": "M03_basic",
      "title": "普攻",
      "kind": "THRUST",
      "power": 1,
      "reach": 145,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "M03_guard",
        "title": "陷阵守御",
        "kind": "WARD",
        "power": 55,
        "reach": 0,
        "cooldown": 14,
        "mana_cost": 36,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "party",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "M03_field",
        "title": "铁壁阵",
        "kind": "NOVA",
        "power": 0.22,
        "reach": 195,
        "cooldown": 18,
        "mana_cost": 42,
        "unlock_level": 8,
        "mechanic": "field",
        "params": {
          "duration": 6,
          "interval": 1,
          "radius": 195,
          "heal": 5,
          "mana": 0,
          "follow": false
        },
        "target_scope": "party",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "M03_support",
      "title": "陷阵护盾",
      "kind": "WARD",
      "power": 26,
      "reach": 0,
      "cooldown": 9,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "armor": 0.16
    },
    "trait": "",
    "trait_params": {}
  },
  "M04": {
    "name": "陈宫",
    "entry_level": 8,
    "base": {
      "hp": 155,
      "mp": 160,
      "attack": 21,
      "armor": 5,
      "speed": 1,
      "move": 195,
      "regen": 4.1
    },
    "basic": {
      "id": "M04_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 480,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "manual": [
      {
        "id": "M04_field",
        "title": "阵前令",
        "kind": "NOVA",
        "power": 0.55,
        "reach": 220,
        "cooldown": 13,
        "mana_cost": 34,
        "unlock_level": 1,
        "mechanic": "field",
        "params": {
          "duration": 7,
          "interval": 1,
          "radius": 220,
          "heal": 0,
          "mana": 0,
          "follow": false
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": true
      },
      {
        "id": "M04_bind",
        "title": "锁魂阵",
        "kind": "NOVA",
        "power": 2.7,
        "reach": 245,
        "cooldown": 15,
        "mana_cost": 40,
        "unlock_level": 8,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0.65,
        "duration": 3,
        "magic": true
      }
    ],
    "automatic": [],
    "support": {
      "id": "M04_support",
      "title": "阵中令",
      "kind": "PROJECTILE",
      "power": 0.8,
      "reach": 520,
      "cooldown": 6,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "expose",
      "params": {
        "duration": 3,
        "multiplier": 0.1
      },
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "owned": {
      "regen": 0.12
    },
    "trait": "",
    "trait_params": {}
  },
  "M05": {
    "name": "曹纯",
    "entry_level": 8,
    "base": {
      "hp": 225,
      "mp": 100,
      "attack": 29,
      "armor": 10,
      "speed": 1.2,
      "move": 225,
      "regen": 2.5
    },
    "basic": {
      "id": "M05_basic",
      "title": "普攻",
      "kind": "THRUST",
      "power": 1,
      "reach": 175,
      "cooldown": 0.8333333333333334,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "M05_dash",
        "title": "虎豹突贯",
        "kind": "THRUST",
        "power": 3.5,
        "reach": 260,
        "cooldown": 9,
        "mana_cost": 32,
        "unlock_level": 1,
        "mechanic": "dash",
        "params": {
          "distance": 160
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "M05_rally",
        "title": "催阵",
        "kind": "WARD",
        "power": 0,
        "reach": 0,
        "cooldown": 16,
        "mana_cost": 35,
        "unlock_level": 8,
        "mechanic": "rally",
        "params": {
          "duration": 5,
          "attack_multiplier": 0.15,
          "speed_multiplier": 0.2
        },
        "target_scope": "party",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "M05_support",
      "title": "骑军掠阵",
      "kind": "THRUST",
      "power": 1.6,
      "reach": 255,
      "cooldown": 6,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "hp": 0.8
    },
    "trait": "",
    "trait_params": {}
  },
  "M06": {
    "name": "曹休",
    "entry_level": 7,
    "base": {
      "hp": 175,
      "mp": 120,
      "attack": 32,
      "armor": 5,
      "speed": 1,
      "move": 220,
      "regen": 3
    },
    "basic": {
      "id": "M06_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 570,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "M06_expose",
        "title": "定点狙击",
        "kind": "PROJECTILE",
        "power": 4.3,
        "reach": 650,
        "cooldown": 11,
        "mana_cost": 35,
        "unlock_level": 1,
        "mechanic": "expose",
        "params": {
          "duration": 4,
          "multiplier": 0.12
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "M06_dash",
        "title": "退阵射",
        "kind": "THRUST",
        "power": 2.5,
        "reach": 480,
        "cooldown": 12,
        "mana_cost": 30,
        "unlock_level": 7,
        "mechanic": "dash",
        "params": {
          "distance": -120
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "M06_support",
      "title": "定射",
      "kind": "PROJECTILE",
      "power": 1.8,
      "reach": 630,
      "cooldown": 7,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "mp": 0.6
    },
    "trait": "",
    "trait_params": {}
  },
  "M07": {
    "name": "臧霸",
    "entry_level": 3,
    "base": {
      "hp": 245,
      "mp": 90,
      "attack": 29,
      "armor": 9,
      "speed": 1.1,
      "move": 205,
      "regen": 2.6
    },
    "basic": {
      "id": "M07_basic",
      "title": "普攻",
      "kind": "SWEEP",
      "power": 1,
      "reach": 145,
      "cooldown": 0.9090909090909091,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "M07_sweep",
        "title": "扫寨",
        "kind": "NOVA",
        "power": 3.4,
        "reach": 220,
        "cooldown": 8,
        "mana_cost": 30,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "M07_rally",
        "title": "聚众",
        "kind": "WARD",
        "power": 0,
        "reach": 0,
        "cooldown": 15,
        "mana_cost": 34,
        "unlock_level": 5,
        "mechanic": "rally",
        "params": {
          "duration": 5,
          "attack_multiplier": 0.2,
          "speed_multiplier": 0.08
        },
        "target_scope": "self",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "M07_support",
      "title": "清围",
      "kind": "NOVA",
      "power": 1.25,
      "reach": 190,
      "cooldown": 5.5,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "hp": 0.7
    },
    "trait": "",
    "trait_params": {}
  },
  "M08": {
    "name": "侯成",
    "entry_level": 5,
    "base": {
      "hp": 230,
      "mp": 105,
      "attack": 25,
      "armor": 14,
      "speed": 1,
      "move": 195,
      "regen": 2.6
    },
    "basic": {
      "id": "M08_basic",
      "title": "普攻",
      "kind": "THRUST",
      "power": 1,
      "reach": 150,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "M08_break",
        "title": "破坚",
        "kind": "THRUST",
        "power": 3,
        "reach": 240,
        "cooldown": 9,
        "mana_cost": 28,
        "unlock_level": 1,
        "mechanic": "expose",
        "params": {
          "duration": 5,
          "multiplier": 0.18
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "M08_guard",
        "title": "固阵",
        "kind": "WARD",
        "power": 44,
        "reach": 0,
        "cooldown": 13,
        "mana_cost": 30,
        "unlock_level": 5,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "M08_support",
      "title": "破甲援刺",
      "kind": "THRUST",
      "power": 1,
      "reach": 205,
      "cooldown": 6,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "expose",
      "params": {
        "duration": 3,
        "multiplier": 0.1
      },
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "armor": 0.12
    },
    "trait": "",
    "trait_params": {}
  },
  "F01": {
    "name": "吕玲绮",
    "entry_level": 9,
    "base": {
      "hp": 190,
      "mp": 110,
      "attack": 34,
      "armor": 5,
      "speed": 1.5,
      "move": 240,
      "regen": 2.6
    },
    "basic": {
      "id": "F01_basic",
      "title": "普攻",
      "kind": "THRUST",
      "power": 1,
      "reach": 145,
      "cooldown": 0.6666666666666666,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "F01_dash",
        "title": "绮锋突进",
        "kind": "THRUST",
        "power": 3.6,
        "reach": 245,
        "cooldown": 8,
        "mana_cost": 32,
        "unlock_level": 1,
        "mechanic": "dash",
        "params": {
          "distance": 140
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "F01_expose",
        "title": "裂阵",
        "kind": "NOVA",
        "power": 4.1,
        "reach": 195,
        "cooldown": 12,
        "mana_cost": 38,
        "unlock_level": 9,
        "mechanic": "expose",
        "params": {
          "duration": 4,
          "multiplier": 0.15
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "F01_support",
      "title": "飞锋援击",
      "kind": "THRUST",
      "power": 1.4,
      "reach": 225,
      "cooldown": 4.5,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "speed": 0.01
    },
    "trait": "",
    "trait_params": {}
  },
  "F02": {
    "name": "蕾娜",
    "entry_level": 5,
    "base": {
      "hp": 200,
      "mp": 100,
      "attack": 26,
      "armor": 10,
      "speed": 1.25,
      "move": 220,
      "regen": 2.8
    },
    "basic": {
      "id": "F02_basic",
      "title": "普攻",
      "kind": "SWEEP",
      "power": 1,
      "reach": 120,
      "cooldown": 0.8,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "F02_guard",
        "title": "守势反击",
        "kind": "WARD",
        "power": 0,
        "reach": 185,
        "cooldown": 9,
        "mana_cost": 24,
        "unlock_level": 1,
        "mechanic": "guard",
        "params": {
          "duration": 2.5,
          "reduction": 0.6,
          "counter_scale": 2.2,
          "charges": 1,
          "radius": 185
        },
        "target_scope": "self",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "F02_riposte",
        "title": "迎锋斩",
        "kind": "THRUST",
        "power": 3.1,
        "reach": 210,
        "cooldown": 8,
        "mana_cost": 30,
        "unlock_level": 5,
        "mechanic": "expose",
        "params": {
          "duration": 3,
          "multiplier": 0.1
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "F02_support",
      "title": "护剑",
      "kind": "WARD",
      "power": 0,
      "reach": 155,
      "cooldown": 8,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "guard",
      "params": {
        "duration": 1.2,
        "reduction": 0.35,
        "counter_scale": 0.8,
        "charges": 1,
        "radius": 155
      },
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "armor": 0.14
    },
    "trait": "",
    "trait_params": {}
  },
  "F03": {
    "name": "田秀",
    "entry_level": 3,
    "base": {
      "hp": 145,
      "mp": 145,
      "attack": 11,
      "armor": 3,
      "speed": 1,
      "move": 200,
      "regen": 4
    },
    "basic": {
      "id": "F03_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 400,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "manual": [
      {
        "id": "physician_heal",
        "title": "回春",
        "kind": "HEAL",
        "power": 48,
        "reach": 0,
        "cooldown": 10,
        "mana_cost": 34,
        "unlock_level": 1,
        "mechanic": "party_heal",
        "params": {
          "shield_cap_ratio": 0.35
        },
        "target_scope": "party",
        "slow": 0,
        "duration": 0,
        "magic": true
      },
      {
        "id": "physician_ward",
        "title": "护命",
        "kind": "WARD",
        "power": 55,
        "reach": 0,
        "cooldown": 16,
        "mana_cost": 42,
        "unlock_level": 5,
        "mechanic": "",
        "params": {},
        "target_scope": "party",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "physician_support",
      "title": "敷药",
      "kind": "HEAL",
      "power": 12,
      "reach": 0,
      "cooldown": 6,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "lowest_hp",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "owned": {
      "armor": 0.12
    },
    "trait": "",
    "trait_params": {}
  },
  "F04": {
    "name": "钱绮罗",
    "entry_level": 3,
    "base": {
      "hp": 160,
      "mp": 135,
      "attack": 15,
      "armor": 4,
      "speed": 1.05,
      "move": 210,
      "regen": 3.4
    },
    "basic": {
      "id": "F04_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 390,
      "cooldown": 0.9523809523809523,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "manual": [
      {
        "id": "F04_settle",
        "title": "集中结账",
        "kind": "MANA",
        "power": 0,
        "reach": 0,
        "cooldown": 12,
        "mana_cost": 18,
        "unlock_level": 1,
        "mechanic": "refund_settle",
        "params": {},
        "target_scope": "party",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "F04_supply",
        "title": "应急补给",
        "kind": "MANA",
        "power": 22,
        "reach": 0,
        "cooldown": 15,
        "mana_cost": 28,
        "unlock_level": 5,
        "mechanic": "",
        "params": {},
        "target_scope": "lowest_mp",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "F04_support",
      "title": "护身碎银",
      "kind": "PROJECTILE",
      "power": 0.55,
      "reach": 410,
      "cooldown": 5,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "owned": {
      "mp": 0.6
    },
    "trait": "refund",
    "trait_params": {
      "fraction": 0.2,
      "duration": 6,
      "ticks": 3
    }
  },
  "F05": {
    "name": "祝青蘅",
    "entry_level": 4,
    "base": {
      "hp": 150,
      "mp": 135,
      "attack": 23,
      "armor": 3,
      "speed": 1,
      "move": 205,
      "regen": 3.6
    },
    "basic": {
      "id": "F05_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 460,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "manual": [
      {
        "id": "F05_curse",
        "title": "青蘅符",
        "kind": "PROJECTILE",
        "power": 1.4,
        "reach": 510,
        "cooldown": 7,
        "mana_cost": 26,
        "unlock_level": 1,
        "mechanic": "curse",
        "params": {
          "duration": 6,
          "spread_fraction": 0.35,
          "spread_targets": 2,
          "spread_radius": 180,
          "dot_scale": 1.44
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": true
      },
      {
        "id": "F05_spread",
        "title": "散咒",
        "kind": "NOVA",
        "power": 1.2,
        "reach": 230,
        "cooldown": 11,
        "mana_cost": 34,
        "unlock_level": 4,
        "mechanic": "curse",
        "params": {
          "dot_scale": 0.9,
          "duration": 6,
          "spread_fraction": 0.65,
          "spread_targets": 3,
          "spread_radius": 230
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": true
      }
    ],
    "automatic": [],
    "support": {
      "id": "F05_support",
      "title": "缠咒",
      "kind": "PROJECTILE",
      "power": 0.45,
      "reach": 480,
      "cooldown": 5,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "curse",
      "params": {
        "duration": 4,
        "dot_scale": 0.48
      },
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "owned": {
      "regen": 0.12
    },
    "trait": "curse",
    "trait_params": {
      "duration": 6,
      "dot_scale": 0.96,
      "interval": 2
    }
  },
  "F06": {
    "name": "秦雁",
    "entry_level": 5,
    "base": {
      "hp": 165,
      "mp": 110,
      "attack": 25,
      "armor": 4,
      "speed": 1.2,
      "move": 210,
      "regen": 3
    },
    "basic": {
      "id": "F06_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 510,
      "cooldown": 0.8333333333333334,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "F06_volley",
        "title": "穿云齐射",
        "kind": "THRUST",
        "power": 1.8,
        "reach": 560,
        "cooldown": 10,
        "mana_cost": 30,
        "unlock_level": 1,
        "mechanic": "ammo_volley",
        "params": {
          "max_spend": 4,
          "bonus_per_arrow": 0.35
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "F06_pin",
        "title": "钉阵矢",
        "kind": "THRUST",
        "power": 2.8,
        "reach": 570,
        "cooldown": 12,
        "mana_cost": 34,
        "unlock_level": 6,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0.45,
        "duration": 2.5,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "F06_support",
      "title": "特制箭追射",
      "kind": "PROJECTILE",
      "power": 1.15,
      "reach": 560,
      "cooldown": 2,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "ammo_followup",
      "params": {
        "normal_multiplier": 0.4
      },
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "speed": 0.009
    },
    "trait": "ammo",
    "trait_params": {
      "capacity": 6,
      "initial": 6,
      "refill_interval": 8,
      "refill_amount": 2,
      "cast_refill": 1,
      "followup_interval": 2
    }
  },
  "F07": {
    "name": "马三娘",
    "entry_level": 3,
    "base": {
      "hp": 175,
      "mp": 95,
      "attack": 31,
      "armor": 2,
      "speed": 1.6,
      "move": 225,
      "regen": 2.2
    },
    "basic": {
      "id": "F07_basic",
      "title": "普攻",
      "kind": "SWEEP",
      "power": 1,
      "reach": 120,
      "cooldown": 0.625,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "bandit_sweep",
        "title": "寨风斩",
        "kind": "NOVA",
        "power": 3,
        "reach": 165,
        "cooldown": 6,
        "mana_cost": 28,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "bandit_thrust",
        "title": "断阵刺",
        "kind": "THRUST",
        "power": 3.2,
        "reach": 230,
        "cooldown": 10,
        "mana_cost": 38,
        "unlock_level": 1,
        "mechanic": "shield_strike",
        "params": {
          "shield_max": 30,
          "shield_ratio": 0.025,
          "reach_bonus": 100
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "bandit_support",
      "title": "援斩",
      "kind": "SWEEP",
      "power": 1.1,
      "reach": 150,
      "cooldown": 4,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0.45,
      "duration": 1.5,
      "magic": false
    },
    "owned": {
      "attack": 0.4
    },
    "trait": "",
    "trait_params": {}
  },
  "F08": {
    "name": "陶小满",
    "entry_level": 3,
    "base": {
      "hp": 205,
      "mp": 100,
      "attack": 24,
      "armor": 9,
      "speed": 1.05,
      "move": 195,
      "regen": 2.8
    },
    "basic": {
      "id": "F08_basic",
      "title": "普攻",
      "kind": "SWEEP",
      "power": 1,
      "reach": 125,
      "cooldown": 0.9523809523809523,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "F08_temper",
        "title": "炉火淬刃",
        "kind": "WARD",
        "power": 0,
        "reach": 155,
        "cooldown": 12,
        "mana_cost": 30,
        "unlock_level": 1,
        "mechanic": "temper",
        "params": {
          "duration": 6,
          "reach_bonus": 50,
          "spark_scale": 0.15,
          "splash_radius": 45
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "F08_break",
        "title": "落锤",
        "kind": "NOVA",
        "power": 3.4,
        "reach": 180,
        "cooldown": 10,
        "mana_cost": 32,
        "unlock_level": 5,
        "mechanic": "expose",
        "params": {
          "duration": 4,
          "multiplier": 0.12
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "F08_support",
      "title": "余火淬刃",
      "kind": "WARD",
      "power": 0,
      "reach": 0,
      "cooldown": 9,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "temper",
      "params": {
        "duration": 3,
        "reach_bonus": 30,
        "spark_scale": 0.1,
        "splash_radius": 45
      },
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "attack": 0.25
    },
    "trait": "",
    "trait_params": {}
  },
  "F09": {
    "name": "柳晚晴",
    "entry_level": 3,
    "base": {
      "hp": 150,
      "mp": 135,
      "attack": 17,
      "armor": 4,
      "speed": 1,
      "move": 210,
      "regen": 3.8
    },
    "basic": {
      "id": "F09_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 420,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "manual": [
      {
        "id": "F09_extend",
        "title": "续一阕",
        "kind": "WARD",
        "power": 0,
        "reach": 0,
        "cooldown": 12,
        "mana_cost": 26,
        "unlock_level": 1,
        "mechanic": "extend",
        "params": {
          "seconds": 3,
          "max_extension": 4,
          "allowed": [
            "echo",
            "temper"
          ]
        },
        "target_scope": "party",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "F09_rally",
        "title": "高歌",
        "kind": "WARD",
        "power": 0,
        "reach": 0,
        "cooldown": 14,
        "mana_cost": 32,
        "unlock_level": 5,
        "mechanic": "rally",
        "params": {
          "duration": 5,
          "attack_multiplier": 0.16,
          "speed_multiplier": 0.12
        },
        "target_scope": "party",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "F09_support",
      "title": "轻歌",
      "kind": "WARD",
      "power": 0,
      "reach": 0,
      "cooldown": 8,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "extend",
      "params": {
        "seconds": 1.5,
        "max_extension": 4,
        "allowed": [
          "echo",
          "temper"
        ]
      },
      "target_scope": "party",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "mp": 0.5
    },
    "trait": "",
    "trait_params": {}
  },
  "F10": {
    "name": "陆知微",
    "entry_level": 5,
    "base": {
      "hp": 165,
      "mp": 130,
      "attack": 16,
      "armor": 5,
      "speed": 1.05,
      "move": 205,
      "regen": 3.4
    },
    "basic": {
      "id": "F10_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 400,
      "cooldown": 0.9523809523809523,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "manual": [
      {
        "id": "F10_ward",
        "title": "整册护身",
        "kind": "WARD",
        "power": 38,
        "reach": 0,
        "cooldown": 12,
        "mana_cost": 24,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "F10_expose",
        "title": "点破",
        "kind": "PROJECTILE",
        "power": 2.4,
        "reach": 460,
        "cooldown": 10,
        "mana_cost": 28,
        "unlock_level": 6,
        "mechanic": "expose",
        "params": {
          "duration": 5,
          "multiplier": 0.14
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": true
      }
    ],
    "automatic": [],
    "support": {
      "id": "F10_support",
      "title": "护行符",
      "kind": "WARD",
      "power": 9,
      "reach": 0,
      "cooldown": 7,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "regen": 0.1
    },
    "trait": "relay",
    "trait_params": {
      "fraction": 0.2,
      "min_cost": 1
    }
  },
  "F11": {
    "name": "艾玛",
    "entry_level": 1,
    "base": {
      "hp": 155,
      "mp": 130,
      "attack": 25,
      "armor": 3,
      "speed": 1.15,
      "move": 205,
      "regen": 4.2
    },
    "basic": {
      "id": "F11_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 470,
      "cooldown": 0.8695652173913044,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "manual": [
      {
        "id": "emma_frost",
        "title": "霜环",
        "kind": "NOVA",
        "power": 1.8,
        "reach": 190,
        "cooldown": 7,
        "mana_cost": 28,
        "unlock_level": 1,
        "mechanic": "echo_record",
        "params": {
          "charges": 2,
          "duration": 12,
          "damage_multiplier": 0.45,
          "slow_multiplier": 0.5
        },
        "target_scope": "active",
        "slow": 0.6,
        "duration": 3,
        "magic": true
      },
      {
        "id": "emma_star",
        "title": "星火",
        "kind": "PROJECTILE",
        "power": 5,
        "reach": 580,
        "cooldown": 11,
        "mana_cost": 42,
        "unlock_level": 3,
        "mechanic": "echo_record",
        "params": {
          "charges": 2,
          "duration": 12,
          "damage_multiplier": 0.45,
          "slow_multiplier": 0.5
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": true
      }
    ],
    "automatic": [
      {
        "id": "emma_ice",
        "title": "冰星",
        "kind": "PROJECTILE",
        "power": 1.8,
        "reach": 480,
        "cooldown": 8,
        "mana_cost": 0,
        "unlock_level": 2,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0.3,
        "duration": 1.8,
        "magic": true
      }
    ],
    "support": {
      "id": "emma_support",
      "title": "术法支援",
      "kind": "PROJECTILE",
      "power": 0.8,
      "reach": 500,
      "cooldown": 3.5,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "owned": {
      "regen": 0.15
    },
    "trait": "echo",
    "trait_params": {
      "charges": 2,
      "duration": 12,
      "damage_multiplier": 0.45,
      "slow_multiplier": 0.5
    }
  },
  "N01": {
    "name": "乡勇刀手",
    "entry_level": 1,
    "base": {
      "hp": 240,
      "mp": 80,
      "attack": 21,
      "armor": 12,
      "speed": 1.1,
      "move": 190,
      "regen": 2
    },
    "basic": {
      "id": "N01_basic",
      "title": "普攻",
      "kind": "SWEEP",
      "power": 1,
      "reach": 104,
      "cooldown": 0.9090909090909091,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "N01_strike",
        "title": "蓄势一击",
        "kind": "SWEEP",
        "power": 3.2,
        "reach": 129,
        "cooldown": 7,
        "mana_cost": 24,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "militia_support",
      "title": "援斩",
      "kind": "SWEEP",
      "power": 0.8,
      "reach": 135,
      "cooldown": 4,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "attack": 0.5
    },
    "trait": "mark",
    "trait_params": {
      "hits": 3,
      "interval": 1
    }
  },
  "N02": {
    "name": "白门盾卒",
    "entry_level": 5,
    "base": {
      "hp": 250,
      "mp": 90,
      "attack": 18,
      "armor": 15,
      "speed": 1,
      "move": 180,
      "regen": 2.3
    },
    "basic": {
      "id": "N02_basic",
      "title": "普攻",
      "kind": "SWEEP",
      "power": 1,
      "reach": 100,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "N02_ward",
        "title": "举盾",
        "kind": "WARD",
        "power": 38,
        "reach": 0,
        "cooldown": 10,
        "mana_cost": 24,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "self",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "N02_support",
      "title": "薄盾",
      "kind": "WARD",
      "power": 12,
      "reach": 0,
      "cooldown": 4,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "armor": 0.12
    },
    "trait": "",
    "trait_params": {}
  },
  "N03": {
    "name": "陷阵盾卫",
    "entry_level": 8,
    "base": {
      "hp": 290,
      "mp": 95,
      "attack": 17,
      "armor": 19,
      "speed": 0.85,
      "move": 170,
      "regen": 2.1
    },
    "basic": {
      "id": "N03_basic",
      "title": "普攻",
      "kind": "THRUST",
      "power": 1,
      "reach": 120,
      "cooldown": 1.1764705882352942,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "N03_guard",
        "title": "陷阵重盾",
        "kind": "WARD",
        "power": 70,
        "reach": 0,
        "cooldown": 17,
        "mana_cost": 34,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "self",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "N03_support",
      "title": "重盾援护",
      "kind": "WARD",
      "power": 32,
      "reach": 0,
      "cooldown": 11,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "hp": 1
    },
    "trait": "",
    "trait_params": {}
  },
  "N04": {
    "name": "乡勇枪手",
    "entry_level": 1,
    "base": {
      "hp": 185,
      "mp": 85,
      "attack": 24,
      "armor": 6,
      "speed": 1,
      "move": 205,
      "regen": 2.1
    },
    "basic": {
      "id": "N04_basic",
      "title": "普攻",
      "kind": "THRUST",
      "power": 1,
      "reach": 165,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "N04_strike",
        "title": "蓄势一击",
        "kind": "THRUST",
        "power": 3.2,
        "reach": 190,
        "cooldown": 7,
        "mana_cost": 24,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "spear_support",
      "title": "援刺",
      "kind": "THRUST",
      "power": 1.2,
      "reach": 210,
      "cooldown": 4.5,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "attack": 0.35
    },
    "trait": "",
    "trait_params": {}
  },
  "N05": {
    "name": "城门戟卒",
    "entry_level": 5,
    "base": {
      "hp": 220,
      "mp": 90,
      "attack": 22,
      "armor": 10,
      "speed": 1,
      "move": 195,
      "regen": 2.2
    },
    "basic": {
      "id": "N05_basic",
      "title": "普攻",
      "kind": "SWEEP",
      "power": 1,
      "reach": 145,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "N05_sweep",
        "title": "戟门拦截",
        "kind": "NOVA",
        "power": 2.2,
        "reach": 200,
        "cooldown": 9,
        "mana_cost": 26,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0.65,
        "duration": 2,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "N05_support",
      "title": "援戟",
      "kind": "SWEEP",
      "power": 1,
      "reach": 190,
      "cooldown": 5,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0.5,
      "duration": 1.5,
      "magic": false
    },
    "owned": {
      "armor": 0.1
    },
    "trait": "",
    "trait_params": {}
  },
  "N06": {
    "name": "陷阵锐卒",
    "entry_level": 8,
    "base": {
      "hp": 225,
      "mp": 90,
      "attack": 26,
      "armor": 9,
      "speed": 0.95,
      "move": 190,
      "regen": 2
    },
    "basic": {
      "id": "N06_basic",
      "title": "普攻",
      "kind": "THRUST",
      "power": 1,
      "reach": 185,
      "cooldown": 1.0526315789473684,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "N06_break",
        "title": "锐卒攻坚",
        "kind": "THRUST",
        "power": 3,
        "reach": 255,
        "cooldown": 9,
        "mana_cost": 28,
        "unlock_level": 1,
        "mechanic": "expose",
        "params": {
          "duration": 4,
          "multiplier": 0.16
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "N06_support",
      "title": "破坚援刺",
      "kind": "THRUST",
      "power": 0.9,
      "reach": 235,
      "cooldown": 6,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "expose",
      "params": {
        "duration": 3,
        "multiplier": 0.1
      },
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "attack": 0.3
    },
    "trait": "",
    "trait_params": {}
  },
  "N07": {
    "name": "猎户弓手",
    "entry_level": 1,
    "base": {
      "hp": 150,
      "mp": 90,
      "attack": 19,
      "armor": 3,
      "speed": 1.45,
      "move": 215,
      "regen": 2.4
    },
    "basic": {
      "id": "N07_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 480,
      "cooldown": 0.6896551724137931,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "N07_strike",
        "title": "蓄势一击",
        "kind": "PROJECTILE",
        "power": 3.2,
        "reach": 505,
        "cooldown": 7,
        "mana_cost": 24,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "bow_support",
      "title": "援射",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 520,
      "cooldown": 3,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "speed": 0.012
    },
    "trait": "mark",
    "trait_params": {
      "hits": 3,
      "interval": 1
    }
  },
  "N08": {
    "name": "白门弩手",
    "entry_level": 5,
    "base": {
      "hp": 175,
      "mp": 95,
      "attack": 25,
      "armor": 6,
      "speed": 0.9,
      "move": 195,
      "regen": 2.3
    },
    "basic": {
      "id": "N08_basic",
      "title": "普攻",
      "kind": "THRUST",
      "power": 1,
      "reach": 510,
      "cooldown": 1.1111111111111112,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "N08_bolt",
        "title": "贯阵弩",
        "kind": "THRUST",
        "power": 3.4,
        "reach": 580,
        "cooldown": 10,
        "mana_cost": 28,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "N08_support",
      "title": "贯穿援射",
      "kind": "THRUST",
      "power": 1.5,
      "reach": 570,
      "cooldown": 7,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "attack": 0.3
    },
    "trait": "",
    "trait_params": {}
  },
  "N09": {
    "name": "曹军劲弩手",
    "entry_level": 7,
    "base": {
      "hp": 170,
      "mp": 100,
      "attack": 26,
      "armor": 5,
      "speed": 1.15,
      "move": 200,
      "regen": 2.5
    },
    "basic": {
      "id": "N09_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 560,
      "cooldown": 0.8695652173913044,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "N09_aim",
        "title": "定敌弩",
        "kind": "PROJECTILE",
        "power": 4,
        "reach": 630,
        "cooldown": 11,
        "mana_cost": 30,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "N09_support",
      "title": "连弩援射",
      "kind": "PROJECTILE",
      "power": 1.2,
      "reach": 610,
      "cooldown": 5,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "mp": 0.5
    },
    "trait": "mark",
    "trait_params": {
      "hits": 4,
      "interval": 2
    }
  },
  "N10": {
    "name": "并州游骑",
    "entry_level": 8,
    "base": {
      "hp": 195,
      "mp": 90,
      "attack": 22,
      "armor": 7,
      "speed": 1.2,
      "move": 240,
      "regen": 2.1
    },
    "basic": {
      "id": "N10_basic",
      "title": "普攻",
      "kind": "THRUST",
      "power": 1,
      "reach": 150,
      "cooldown": 0.8333333333333334,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "N10_dash",
        "title": "游骑突围",
        "kind": "THRUST",
        "power": 2.7,
        "reach": 215,
        "cooldown": 9,
        "mana_cost": 25,
        "unlock_level": 1,
        "mechanic": "dash",
        "params": {
          "distance": 150
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "N10_support",
      "title": "冲阵",
      "kind": "THRUST",
      "power": 1.2,
      "reach": 225,
      "cooldown": 5.5,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "move": 0.45
    },
    "trait": "",
    "trait_params": {}
  },
  "N11": {
    "name": "虎豹轻骑",
    "entry_level": 7,
    "base": {
      "hp": 190,
      "mp": 95,
      "attack": 24,
      "armor": 6,
      "speed": 1.35,
      "move": 250,
      "regen": 2.2
    },
    "basic": {
      "id": "N11_basic",
      "title": "普攻",
      "kind": "THRUST",
      "power": 1,
      "reach": 155,
      "cooldown": 0.7407407407407407,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "N11_dash",
        "title": "轻骑逐敌",
        "kind": "THRUST",
        "power": 2.8,
        "reach": 250,
        "cooldown": 8,
        "mana_cost": 26,
        "unlock_level": 1,
        "mechanic": "dash",
        "params": {
          "distance": 180
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "N11_support",
      "title": "掠锋",
      "kind": "THRUST",
      "power": 0.9,
      "reach": 265,
      "cooldown": 4,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0.3,
      "duration": 1,
      "magic": false
    },
    "owned": {
      "move": 0.35
    },
    "trait": "",
    "trait_params": {}
  },
  "N12": {
    "name": "虎豹重骑",
    "entry_level": 8,
    "base": {
      "hp": 270,
      "mp": 90,
      "attack": 28,
      "armor": 16,
      "speed": 0.8,
      "move": 185,
      "regen": 2
    },
    "basic": {
      "id": "N12_basic",
      "title": "普攻",
      "kind": "THRUST",
      "power": 1,
      "reach": 195,
      "cooldown": 1.25,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "N12_charge",
        "title": "重骑压阵",
        "kind": "THRUST",
        "power": 3.8,
        "reach": 285,
        "cooldown": 14,
        "mana_cost": 32,
        "unlock_level": 1,
        "mechanic": "dash",
        "params": {
          "distance": 110
        },
        "target_scope": "active",
        "slow": 0.65,
        "duration": 2,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "N12_support",
      "title": "重冲",
      "kind": "THRUST",
      "power": 1.8,
      "reach": 275,
      "cooldown": 8,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0.55,
      "duration": 1.5,
      "magic": false
    },
    "owned": {
      "armor": 0.12
    },
    "trait": "",
    "trait_params": {}
  },
  "N13": {
    "name": "游方符师",
    "entry_level": 1,
    "base": {
      "hp": 145,
      "mp": 140,
      "attack": 16,
      "armor": 3,
      "speed": 1,
      "move": 200,
      "regen": 5
    },
    "basic": {
      "id": "N13_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 400,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "manual": [
      {
        "id": "N13_strike",
        "title": "蓄势一击",
        "kind": "PROJECTILE",
        "power": 2.8,
        "reach": 460,
        "cooldown": 8,
        "mana_cost": 24,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": true
      },
      {
        "id": "N13_mana",
        "title": "回元符",
        "kind": "MANA",
        "power": 24,
        "reach": 0,
        "cooldown": 14,
        "mana_cost": 34,
        "unlock_level": 4,
        "mechanic": "",
        "params": {},
        "target_scope": "lowest_mp",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "talisman_support",
      "title": "回元",
      "kind": "MANA",
      "power": 6,
      "reach": 0,
      "cooldown": 5,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "lowest_mp",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "regen": 0.25
    },
    "trait": "",
    "trait_params": {}
  },
  "N14": {
    "name": "荒祠咒师",
    "entry_level": 4,
    "base": {
      "hp": 145,
      "mp": 125,
      "attack": 20,
      "armor": 3,
      "speed": 1,
      "move": 200,
      "regen": 3.5
    },
    "basic": {
      "id": "N14_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 460,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "manual": [
      {
        "id": "curse_bind",
        "title": "缚行咒",
        "kind": "NOVA",
        "power": 2,
        "reach": 210,
        "cooldown": 9,
        "mana_cost": 30,
        "unlock_level": 1,
        "mechanic": "curse",
        "params": {
          "duration": 6,
          "dot_scale": 1.08
        },
        "target_scope": "active",
        "slow": 0.65,
        "duration": 3.5,
        "magic": true
      }
    ],
    "automatic": [],
    "support": {
      "id": "curse_support",
      "title": "缚行咒",
      "kind": "PROJECTILE",
      "power": 0.65,
      "reach": 480,
      "cooldown": 4.5,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "curse",
      "params": {
        "duration": 4,
        "dot_scale": 0.4
      },
      "target_scope": "active",
      "slow": 0.4,
      "duration": 2,
      "magic": true
    },
    "owned": {
      "regen": 0.12
    },
    "trait": "curse",
    "trait_params": {
      "duration": 5,
      "dot_scale": 0.5,
      "interval": 2
    }
  },
  "N15": {
    "name": "曹军祭师",
    "entry_level": 7,
    "base": {
      "hp": 155,
      "mp": 130,
      "attack": 19,
      "armor": 4,
      "speed": 0.95,
      "move": 195,
      "regen": 3.8
    },
    "basic": {
      "id": "N15_basic",
      "title": "普攻",
      "kind": "PROJECTILE",
      "power": 1,
      "reach": 470,
      "cooldown": 1.0526315789473684,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "manual": [
      {
        "id": "N15_curse",
        "title": "祭咒",
        "kind": "PROJECTILE",
        "power": 1.8,
        "reach": 510,
        "cooldown": 8,
        "mana_cost": 26,
        "unlock_level": 1,
        "mechanic": "curse",
        "params": {
          "duration": 5,
          "dot_scale": 1.0
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": true
      },
      {
        "id": "N15_cashout",
        "title": "催咒",
        "kind": "PROJECTILE",
        "power": 2,
        "reach": 530,
        "cooldown": 12,
        "mana_cost": 34,
        "unlock_level": 7,
        "mechanic": "curse_cashout",
        "params": {
          "fraction": 1
        },
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": true
      }
    ],
    "automatic": [],
    "support": {
      "id": "N15_support",
      "title": "弱敌咒",
      "kind": "PROJECTILE",
      "power": 0.65,
      "reach": 520,
      "cooldown": 6,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "expose",
      "params": {
        "duration": 3,
        "multiplier": 0.1
      },
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": true
    },
    "owned": {
      "mp": 0.6
    },
    "trait": "",
    "trait_params": {}
  },
  "N16": {
    "name": "行脚郎中",
    "entry_level": 1,
    "base": {
      "hp": 170,
      "mp": 120,
      "attack": 14,
      "armor": 4,
      "speed": 1,
      "move": 200,
      "regen": 3.2
    },
    "basic": {
      "id": "N16_basic",
      "title": "普攻",
      "kind": "SWEEP",
      "power": 1,
      "reach": 95,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "healer_aid",
        "title": "急救",
        "kind": "HEAL",
        "power": 45,
        "reach": 0,
        "cooldown": 12,
        "mana_cost": 32,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "lowest_hp",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "healer_support",
      "title": "敷药",
      "kind": "HEAL",
      "power": 7,
      "reach": 0,
      "cooldown": 7,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "lowest_hp",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "supply_hp": 0.025
    },
    "trait": "",
    "trait_params": {}
  },
  "N17": {
    "name": "随军伙夫",
    "entry_level": 1,
    "base": {
      "hp": 205,
      "mp": 95,
      "attack": 17,
      "armor": 6,
      "speed": 1.1,
      "move": 205,
      "regen": 2.6
    },
    "basic": {
      "id": "N17_basic",
      "title": "普攻",
      "kind": "SWEEP",
      "power": 1,
      "reach": 100,
      "cooldown": 0.9090909090909091,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "cook_guard",
        "title": "护身",
        "kind": "WARD",
        "power": 45,
        "reach": 0,
        "cooldown": 12,
        "mana_cost": 30,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "self",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "cook_support",
      "title": "热汤",
      "kind": "HEAL",
      "power": 4,
      "reach": 0,
      "cooldown": 5,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "lowest_hp",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "supply_mp": 0.04
    },
    "trait": "",
    "trait_params": {}
  },
  "N18": {
    "name": "军需小吏",
    "entry_level": 3,
    "base": {
      "hp": 170,
      "mp": 105,
      "attack": 12,
      "armor": 5,
      "speed": 1,
      "move": 200,
      "regen": 3.2
    },
    "basic": {
      "id": "N18_basic",
      "title": "普攻",
      "kind": "SWEEP",
      "power": 1,
      "reach": 100,
      "cooldown": 1.0,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "",
      "params": {},
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "manual": [
      {
        "id": "clerk_guard",
        "title": "护身符",
        "kind": "WARD",
        "power": 45,
        "reach": 0,
        "cooldown": 13,
        "mana_cost": 30,
        "unlock_level": 1,
        "mechanic": "",
        "params": {},
        "target_scope": "active",
        "slow": 0,
        "duration": 0,
        "magic": false
      },
      {
        "id": "N18_rally",
        "title": "行军令",
        "kind": "WARD",
        "power": 0,
        "reach": 0,
        "cooldown": 15,
        "mana_cost": 28,
        "unlock_level": 5,
        "mechanic": "rally",
        "params": {
          "duration": 4,
          "attack_multiplier": 0.1,
          "speed_multiplier": 0.1
        },
        "target_scope": "party",
        "slow": 0,
        "duration": 0,
        "magic": false
      }
    ],
    "automatic": [],
    "support": {
      "id": "clerk_support",
      "title": "军需援护",
      "kind": "WARD",
      "power": 0,
      "reach": 0,
      "cooldown": 7,
      "mana_cost": 0,
      "unlock_level": 1,
      "mechanic": "rally",
      "params": {
        "duration": 2,
        "attack_multiplier": 0.06,
        "speed_multiplier": 0.04
      },
      "target_scope": "active",
      "slow": 0,
      "duration": 0,
      "magic": false
    },
    "owned": {
      "supply_mp": 0.03
    },
    "trait": "",
    "trait_params": {}
  }
}
