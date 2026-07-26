# 安全指南

完整政策见仓库根目录 [`SECURITY.md`](../../SECURITY.md)。

- 本地 JSON 位于 `user://`，不加密，依赖操作系统用户边界。
- Supabase 两张表启用并强制 RLS；客户端不能直接读写表。
- 最终积分只由 `submit_score` 在数据库计算；`get_leaderboard` 不返回 UUID。
- publishable key 可以分发，但权限完全受 grants/RLS 限制。
- `service_role`、密码、token、keystore、证书、profile 和私钥不得进入客户端、
  Git、日志或交付包。
- 匿名排行榜无法阻止新 UUID、修改客户端或伪造合理指标，不用于严肃竞技。
- CI 将第三方 Action 固定到不可变提交，并在执行前用官方 SHA-512 清单
  校验 Godot 4.7.1 归档。
- 漏洞应通过 GitHub 私密漏洞报告提交，不要先公开利用细节。

泄露后应立即轮换、清理当前文件和产物、评估 Git 历史并重新生成受影响发布。
