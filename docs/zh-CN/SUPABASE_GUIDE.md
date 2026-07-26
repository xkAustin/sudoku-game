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
