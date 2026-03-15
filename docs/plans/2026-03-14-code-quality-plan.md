# Code Quality 实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development to implement this plan.

**Goal:** 为 lbpSSH 添加代码质量分析和 CI 集成

**Tech Stack:** dart_code_metrics, GitHub Actions

---

## Chunk 1: dart_code_metrics 集成

### 任务 2.1: 添加代码度量依赖

- [ ] **Step 1: 添加 dart_code_metrics 到 pubspec.yaml**

```yaml
dev_dependencies:
  dart_code_metrics: ^5.7.0
```

- [ ] **Step 2: 运行 pub get**

Run: `flutter pub get`

- [ ] **Step 3: 更新 analysis_options.yaml**

```yaml
dart_code_metrics:
  metrics:
    cyclomatic-complexity: 20
    lines-of-code: 100
    number-of-parameters: 5
  rules:
    - avoid-unnecessary-containers
    - prefer-const-declarations
```

- [ ] **Step 4: 运行分析**

Run: `flutter pub run dart_code_metrics analyze lib/`

- [ ] **Step 5: 提交**

```bash
git add pubspec.yaml analysis_options.yaml
git commit -m "chore(quality): add dart_code_metrics"
```

---

### 任务 2.2: 集成 GitHub Actions

- [ ] **Step 1: 更新 .github/workflows/ci.yml**

```yaml
- name: Code Quality
  run: flutter pub run dart_code_metrics analyze lib/ || true
```

- [ ] **Step 2: 提交**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add code quality check"
```

---

## 总结

| 任务 | 描述 |
|------|------|
| 2.1 | 添加 dart_code_metrics |
| 2.2 | 集成 GitHub Actions |

共 2 个提交
