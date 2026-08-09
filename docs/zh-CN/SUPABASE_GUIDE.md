# Supabase 指南

## 客户端环境变量

```sh
cp config/client.env.example config/client.env
```

```dotenv
SUPABASE_URL=https://YOUR_PROJECT.supabase.co/rest/v1/
SUPABASE_KEY=your-publishable-key
```

`config/client.env` 已忽略。不得填写 secret 或 `service_role` key。

## 部署 migration

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db query --linked \
  --file backend/supabase/migrations/006_data_api_scores.sql
supabase db query --linked \
  --file backend/supabase/tests/explain_leaderboard_queries.sql \
  --output json
supabase db query --linked \
  --file backend/supabase/migrations/009_data_api_leaderboard_performance.sql
```

该 migration 创建 `scores`、`score_submission_guards`、
`scores_global_rank`、`normalize_player_name`、`calculate_ranked_score`、
`submit_score` 和 `get_leaderboard`。两张表强制 RLS，无客户端表策略和直接
表权限；匿名客户端只可执行两个公开 RPC。当前 migration 不创建 trigger。
计划脚本仅使用 `pg_temp` 数据，并在目标 PostgreSQL 版本上比较完整排名物化
与 migration 009 的候选实现。

## 结构与安全验证

```sh
supabase db query --linked \
  --file backend/supabase/tests/verify_data_api_scores.sql \
  --output table
./backend/supabase/tests/live_data_api.sh
godot --headless --path . --script tests/supabase_live_runner.gd
```

实时测试会创建 QA 排行榜行；使用输出的 UUID，通过管理员连接清理
`score_submission_guards` 和 `scores`。不要把 service-role key 写进测试脚本。

本方案只提供休闲排行榜基础防作弊。服务器计算最终分数并验证指标，但匿名
UUID 和客户端指标仍可伪造。

2026-08-09 的基准与线上测试在 20,000 条代表性数据下测得：最差排名提升
5.34×，最佳排名提升 43.65×。Migration 009 后完整 Data API 流程通过，
并已按精确 UUID 删除测试成绩和守卫记录。

## 可选签名挑战函数

部署可选 Edge Functions 前，先应用其私有原子提交 migration：

新项目应先按文件名顺序应用 `backend/supabase/edge_migrations/` 中的全部文件。
以下命令用于已具备 migration 001–006 的现有 Edge schema 升级。

```sh
supabase db query --linked \
  --file backend/supabase/edge_migrations/007_atomic_edge_submissions.sql
supabase db query --linked \
  --file backend/supabase/edge_migrations/008_edge_service_permissions.sql
supabase db query --linked \
  --file backend/supabase/tests/explain_edge_queries.sql \
  --output json
supabase db query --linked \
  --file backend/supabase/edge_migrations/009_edge_query_performance.sql
supabase functions deploy \
  get-ranked-challenge submit-score get-leaderboard \
  --workdir backend --use-api
./backend/supabase/tests/live_edge_functions.sh
```

Edge migration 008 仅为 Edge 运行时显式授予读取私有表和视图所需的最小权限，
客户端直连权限仍保持撤销。Edge migration 007 按安装 ID 加锁，在同一事务内检查
滚动一分钟限额并写入已验证成绩。
Edge 提交处理器还会流式统计实际请求字节，因此缺失或伪造
`Content-Length` 无法绕过 16 KiB 限制。
特权 Data API 请求使用 8 秒默认超时；排行榜会并发读取相互独立的 Top 100
和本人排名。Edge 基准在会话临时表生成 50,000 行，只有当两个索引在目标
计划中确有收益时才应用 Edge migration 009。使用本地或一次性数据库验证：

```sh
psql "$DATABASE_URL" \
  --set ON_ERROR_STOP=1 \
  --file backend/supabase/tests/test_atomic_edge_submissions.sql
```

验证事务会回滚全部测试数据。

部署前使用两个独立的空 PostgreSQL 17 数据库验证两条 migration 链：

```sh
./backend/supabase/tests/clean_boot.sh
```

该测试会拒绝重复 migration 版本，重复应用两条 migration 链和 Edge seed 以验证
幂等性，并验证必需对象、强制 RLS、授权、性能索引和 Edge 原子提交事务。

2026-08-09 部署前基准测得限流查询提升 1.71×、挑战排行榜提升 2.23×。
部署后，三个函数均为启用 JWT 验证的 `ACTIVE` version 3；无写入线上冒烟
依次得到预期的 401、200、404 和 400 响应。
