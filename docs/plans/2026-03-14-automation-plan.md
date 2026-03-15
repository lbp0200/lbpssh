# 自动化运维实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development to implement this plan.

**Goal:** 添加 Dependabot、Release 自动化和 CHANGELOG 生成

**Tech Stack:** GitHub Actions, Dependabot, Release Drafter

---

## 任务 1: 添加 Dependabot 配置

- [ ] **Step 1: 创建 `.github/dependabot.yml`**

```yaml
version: 2
updates:
  - package-ecosystem: "pub"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

- [ ] **Step 2: 提交**

```bash
git add .github/dependabot.yml
git commit -m "ci: add Dependabot for dependency updates"
```

---

## 任务 2: 添加 Release Drafter

- [ ] **Step 1: 创建 `.github/release-drafter.yml`**

```yaml
name-template: 'v$RESOLVED_VERSION'
tag-template: 'v$RESOLVED_VERSION'
categories:
  - title: 'Features'
    label: 'feature'
  - title: 'Bug Fixes'
    label: 'bug'
  - title: 'Maintenance'
    label: 'chore'
template: |
  ## Changes
  $CHANGES
```

- [ ] **Step 2: 创建 `.github/workflows/release-drafter.yml`**

```yaml
name: Release Drafter
on:
  push:
    branches:
      - main
jobs:
  update_release_draft:
    runs-on: ubuntu-latest
    steps:
      - uses: release-drafter/release-drafter@v5
        with:
          config-name: release-drafter.yml
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

- [ ] **Step 3: 提交**

```bash
git add .github/
git commit -m "ci: add Release Drafter for automated releases"
```

---

## 任务 3: 添加 CHANGELOG 自动化

- [ ] **Step 1: 创建 `.github/workflows/changelog.yml`**

```yaml
name: Changelog
on:
  push:
    branches:
      - main
jobs:
  changelog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Generate CHANGELOG
        run: |
          git log --pretty=format:"- %s (%h)" HEAD~20..HEAD > CHANGELOG.md
      - name: Commit CHANGELOG
        run: |
          git config --local user.email "github-actions[bot]@users.noreply.github.com"
          git config --local user.name "github-actions[bot]"
          git add CHANGELOG.md
          git commit -m "docs: update CHANGELOG" || echo "No changes"
```

- [ ] **Step 2: 提交**

```bash
git add .github/workflows/changelog.yml
git commit -m "ci: add CHANGELOG automation"
```

---

## 总结: 3 个提交
