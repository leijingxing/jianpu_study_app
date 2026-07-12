# ADR-0001：采用 Riverpod 与 go_router

## 状态

Accepted

## 背景

旧实现由页面直接创建存储、网络及平台对象，并通过散落的 `Navigator` 调用组织页面。该结构难以替换依赖、隔离并发请求和验证生命周期。

## 决策

应用使用不依赖代码生成的 Riverpod Provider/Notifier 进行状态管理和依赖注入，使用 go_router 集中定义路由。基础设施对象只在 composition root 创建，并通过 Repository 接口暴露给 ViewModel。

## 替代方案

- Provider：迁移成本较低，但异步状态、依赖覆盖和作用域能力较弱。
- Bloc：边界明确，但会为当前规模引入更多事件样板代码。
- 保留 Navigator：无法满足集中路由与可测试重定向要求。

## 迁移与退出策略

功能按垂直切片迁移到 V2。新页面完成自动化覆盖后直接删除相应旧页面。若未来退出 Riverpod，Repository 和领域模型保持纯 Dart，使替换仅影响 composition root、ViewModel provider 与 View。
