# Multi-Platform Testing 实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development to implement this plan.

**Goal:** 为 lbpSSH 添加多平台构建测试

**Tech Stack:** GitHub Actions, Codemagic

---

## Chunk 1: GitHub Actions 多平台构建

### 任务 3.1: 更新 CI 构建矩阵

- [ ] **Step 1: 更新 .github/workflows/ci.yml**

```yaml
jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        platform: [macos-latest, ubuntu-latest, windows-latest]
    runs-on: ${{ matrix.platform }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
      - run: flutter pub get
      - run: flutter build linux --release
        if: matrix.platform == 'ubuntu-latest'
      - run: flutter build macos --release
        if: matrix.platform == 'macos-latest'
      - run: flutter build windows --release
        if: matrix.platform == 'windows-latest'
```

- [ ] **Step 2: 提交**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add multi-platform build matrix"
```

---

## Chunk 2: Codemagic 配置 (可选)

### 任务 3.2: 添加 Codemagic

- [ ] **Step 1: 创建 codemagic.yaml**

```yaml
workflows:
  desktop:
    name: Desktop CI
    max_build_duration: 60
    environment:
      flutter: stable
    scripts:
      - flutter pub get
      - flutter test
      - flutter build linux --release
      - flutter build macos --release
      - flutter build windows --release
    artifacts:
      - build/linux/**/release/bundle/*
      - build/macos/Build/Products/Release/*
      - build/windows/runner/Release/*
```

- [ ] **Step 2: 提交**

```bash
git add codemagic.yaml
git commit -m "ci: add Codemagic configuration"
```

---

## 总结

| 任务 | 描述 |
|------|------|
| 3.1 | GitHub Actions 多平台构建 |
| 3.2 | Codemagic 配置 (可选) |

共 2 个提交
