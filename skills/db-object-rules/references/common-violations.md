# VIII. 常見違規速查

| 違規類型                 | 典型錯誤                                 | 正確寫法                       |
| -------------------- | ------------------------------------ | -------------------------- |
| 使用雙引號                | `"OWNER"."ACCOUNT"`                  | `OWNER.ACCOUNT`            |
| 小寫 Object 名稱         | `role_info`                          | `ROLE_INFO`                |
| 缺少 Schema Owner      | `ACCOUNT`                            | `OWNER.ACCOUNT`            |
| 名稱以數字開頭              | `2ITEM`                              | `ITEM2`                    |
| 使用非底線符號              | `ROLE-INFO`                          | `ROLE_INFO`                |
| 語句無分號結尾              | `COMMENT ON TABLE OWNER.TEST IS 'x'` | 末尾加 `;`                    |
| DML 無 COMMIT         | `UPDATE ... SET ...`                 | 末尾加 `COMMIT;`              |
| 字串未加引號               | `VALUES (HERO, 18)`                  | `VALUES ('HERO', 18)`      |
| 空白行在 DDL 內           | 欄位定義間有空行                             | 移除空行                       |
| MongoDB 無 Validation | `db.createCollection('X')`           | 加入 `$jsonSchema` validator |
| MongoDB 缺少 `_id`     | `required: ['COL1']`                 | 需包含 `_id`                  |
