# 維護協議:誰能改什麼、怎麼改

> 修改 CLAUDE.md、governance/、skill、`.claude/agents/` 之前必讀。
> 目的:讓制度能被弱模型長期維護而不腐化。撰於 2026-07-05。

---

## 1. 權限分級

| 檔案/區域 | 弱模型可自行改? | 條件 |
|---|---|---|
| `governance/lessons.md`(踩雷教訓,見 §3) | ✅ 可,鼓勵 | 照 §3 格式追加;不可刪別人的條目 |
| `governance/model-dispatch.md` **第 0 節查證表** | ✅ 可 | 僅限「用官方來源重新查證後更新數值+日期」;改規則本身要問 |
| `governance/backup/` | ✅ 可(只增不刪) | 備份檔永不刪除、永不修改 |
| `.claude/agents/*.md`(新增常用 subagent 角色) | ✅ 可新增 | frontmatter 欄位照 model-dispatch.md §0;新增後在 lessons.md 記一行 |
| `governance/diagnosis.md`、`judgment-rubrics.md`、`prompt-templates.md`、`model-dispatch.md`(規則本文) | ⚠️ 先問使用者 | 提出 diff 給使用者確認後才改;改前必備份 |
| `CLAUDE.md` | ⚠️ 先問使用者 | 同上;且改後仍須 ≤150 行、只做索引 |
| `governance/handover-letter.md` | ❌ 不改 | 這是一次性歷史文件;新教訓寫 lessons.md |
| 各 skill 的 `SKILL.md` | ⚠️ 先問使用者 | 改了必同步 CHANGELOG.md(CLAUDE.md 硬規則) |
| `knowledge/`(KB 內容) | 依 CLAUDE.md KB 整合規範 | 不歸本協議管 |

**判斷原則**:影響「未來所有 session 行為」的規則=先問;只是「記錄事實/教訓/查證結果」=可自行。

## 2. 修改流程(適用所有 ⚠️ 項目)

1. 備份:`cp {檔} governance/backup/{檔名}.{YYYY-MM-DD}.bak`(同日多次改,加 `-2`、`-3` 序號)。
   ✅ 項目(lessons.md 追加、查證表更新)免備份;⚠️ 項目一律備份。
2. 寫入前,先依 `skills/update-kb/SKILL.md` 的「去識別化檢查清單」跑一輪雙軌掃描(regex 掃描
   ＋語意比對,尤其留意新增的「Context/起因」段落與版本註記)——本協議涵蓋的路徑(CLAUDE.md、
   governance/、skill、`.claude/agents/`)本來就在該清單「專案 KB 以外」的適用範圍內,不是只
   靠主觀判斷。(起因:2026-07-08 發現 REVIEW_GUIDE 版本註記與 code-architect CHANGELOG 的
   Context 段落直接洩漏真實業務詞彙與類別名,詳見 lessons.md 同日條目)
3. 向使用者展示:改什麼(前後對照)、為什麼、影響哪些情境。
4. 使用者同意後才寫入。
5. 若改動源自一次踩雷,同時在 lessons.md 記錄(§3)。

## 3. 踩雷教訓寫回哪裡、什麼格式

**寫回 `governance/lessons.md`**(不存在就建立,本協議即授權)。什麼算「踩雷」:
同一問題耗掉兩輪以上重試、使用者糾正了你的做法、或你發現制度檔的規則與現實不符。

每條格式(固定四行,追加到檔尾):

```
## {YYYY-MM-DD} {一句話標題}
- 情境:{什麼任務、什麼環境下發生}
- 教訓:{哪個假設錯了/哪條規則缺了}
- 以後怎麼做:{可直接執行的一句話,弱模型看得懂}
```

規則:
- 一條一個教訓,不寫長篇;超過 8 行就是在寫文章,砍掉重寫。
- 與既有條目重複 → 不新增,在舊條目後追加 `(再次發生:YYYY-MM-DD)`。
- 教訓若與 diagnosis.md / judgment-rubrics.md 的既有規則**矛盾**,不要直接改規則檔——記入 lessons.md 並標 `[規則衝突]`,下次與使用者對話時提出。

## 4. 累積多長要精簡

| 檔案 | 門檻 | 動作 |
|---|---|---|
| `lessons.md` | >100 行或 >15 條 | 提議使用者做一次整併:重複合併、已寫入規則檔的刪除、僅存活躍教訓 |
| `CLAUDE.md` | >150 行 | 立即精簡(硬上限),長內容移到 governance/ 並留路由列 |
| governance/ 其他單檔 | >250 行 | 下次修改時提議拆分或精簡 |
| memory(`MEMORY.md` 索引) | >30 行 | 整併重複、刪過時 |
| `governance/backup/` | >30 個檔 | 提議使用者刪除 6 個月以上的備份(需使用者同意) |

精簡的原則:**刪掉的是重複與過時,不是細節**。規則的正反例、判準數字(300 行、3 檔、兩次)是制度的核心,精簡時不可拿掉。

## 5. 查證表的保鮮

`model-dispatch.md` §0 的查證表帶有查證日期。任何 session 若發現:
- 查證日期距今 **超過 60 天**,且本次任務依賴該表 → 先派 claude-code-guide(haiku)重新查證再使用,並更新表格與日期(此更新屬 ✅ 可自行)。
- 表中資料與實測不符(例如 model ID 404)→ 立即重查證+更新+記 lessons.md。
