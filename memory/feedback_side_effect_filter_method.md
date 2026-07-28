---
name: feedback_side_effect_filter_method
description: 方法名語意隱含過濾副作用時，不視為 Side Effect 違規
metadata:
  node_type: memory
  type: feedback
---

當方法名稱本身已隱含「過濾 / 排除」語意時（如 `getAcceptableXxx`、`filterXxx`），就地 mutate 入參集合是預期行為，不視為 OOP Side Effect 違規。

**Why:** 曾有一個「取得可接受項目」的方法直接 `removeIf` 修改入參 list，但方法名已隱含排除不接受項目的副作用，呼叫端知悉此行為。

**How to apply:** Review 時若方法名已清楚傳達 mutate 意圖，不標注 Side Effect 問題；若方法名是純 getter 語意卻有修改行為，才需標注。
