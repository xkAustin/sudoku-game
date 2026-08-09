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
```

该 migration 创建 `scores`、`score_submission_guards`、
`scores_global_rank`、`normalize_player_name`、`calculate_ranked_score`、
`submit_score` 和 `get_leaderboard`。两张表强制 RLS，无客户端表策略和直接
表权限；匿名客户端只可执行两个公开 RPC。当前 migration 不创建 trigger。

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

## 可选签名挑战函数

部署可选 Edge Functions 前，先应用其私有原子提交 migration：

```sh
supabase db query --linked \
  --file backend/supabase/migrations/007_atomic_edge_submissions.sql
supabase db query --linked \
  --file backend/supabase/migrations/008_edge_service_permissions.sql
```

Migration 008 仅为 Edge 运行时显式授予读取私有表和视图所需的最小权限，
客户端直连权限仍保持撤销。Migration 007 按安装 ID 加锁，在同一事务内检查
滚动一分钟限额并写入已验证成绩。
Edge 提交处理器还会流式统计实际请求字节，因此缺失或伪造
`Content-Length` 无法绕过 16 KiB 限制。使用本地或一次性数据库验证：

```sh
psql "$DATABASE_URL" \
  --set ON_ERROR_STOP=1 \
  --file backend/supabase/tests/test_atomic_edge_submissions.sql
```

验证事务会回滚全部测试数据。
