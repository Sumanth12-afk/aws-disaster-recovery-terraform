# Contributing to AWS DRaaS

First off, thank you for considering contributing to AWS DRaaS! It's people like you that make this project better for everyone.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Testing](#testing)

---

## 🤝 Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

### Our Standards

**Positive behavior includes:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Unacceptable behavior includes:**
- Trolling, insulting/derogatory comments, and personal attacks
- Public or private harassment
- Publishing others' private information without explicit permission
- Other conduct which could reasonably be considered inappropriate

---

## 🎯 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

**Bug Report Template:**
```markdown
**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Run command '...'
2. See error '...'

**Expected behavior**
What you expected to happen.

**Actual behavior**
What actually happened.

**Environment:**
- OS: [e.g., Windows 10, macOS 13, Ubuntu 22.04]
- Terraform version: [e.g., 1.6.0]
- AWS CLI version: [e.g., 2.13.0]
- Python version: [e.g., 3.12]

**Logs**
```
Paste relevant logs here
```

**Additional context**
Any other context about the problem.
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

**Enhancement Template:**
```markdown
**Is your feature request related to a problem?**
A clear description of what the problem is. Ex. I'm always frustrated when [...]

**Describe the solution you'd like**
A clear description of what you want to happen.

**Describe alternatives you've considered**
Any alternative solutions or features you've considered.

**Additional context**
Any other context or screenshots about the feature request.
```

### Your First Code Contribution

Unsure where to begin? Look for issues labeled:
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention needed
- `documentation` - Documentation improvements

---

## 🚀 Getting Started

### Prerequisites

1. **Install required tools:**
   ```bash
   # Terraform
   terraform --version  # Should be >= 1.0
   
   # AWS CLI
   aws --version  # Should be >= 2.0
   
   # Python
   python3 --version  # Should be >= 3.8
   ```

2. **Fork the repository:**
   - Click "Fork" button on GitHub
   - Clone your fork:
     ```bash
     git clone https://github.com/YOUR_USERNAME/aws-draas-terraform.git
     cd aws-draas-terraform
     ```

3. **Add upstream remote:**
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/aws-draas-terraform.git
   ```

4. **Configure AWS credentials:**
   ```bash
   aws configure
   ```

5. **Set up development environment:**
   ```bash
   cd drass-terraform
   terraform init
   ```

---

## 🔄 Development Workflow

### 1. Create a Branch

Always create a new branch for your work:

```bash
# Update your fork
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/your-feature-name

# Or for bug fixes
git checkout -b fix/bug-description
```

### Branch Naming Convention:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Test improvements
- `chore/` - Maintenance tasks

### 2. Make Changes

```bash
# Make your changes
vim drass-terraform/main.tf

# Format Terraform code
terraform fmt -recursive

# Validate syntax
terraform validate

# Test your changes
terraform plan
```

### 3. Commit Changes

```bash
git add .
git commit -m "feat: add support for Aurora PostgreSQL"
```

### 4. Push Changes

```bash
git push origin feature/your-feature-name
```

### 5. Create Pull Request

1. Go to your fork on GitHub
2. Click "Pull Request"
3. Fill in the PR template
4. Wait for review

---

## 📝 Coding Standards

### Terraform Standards

**File Organization:**
```
modules/
  module-name/
    ├── main.tf          # Main resource definitions
    ├── variables.tf     # Input variables
    ├── outputs.tf       # Output values
    ├── providers.tf     # Provider requirements
    └── README.md        # Module documentation
```

**Naming Conventions:**
```hcl
# Resources: use underscores
resource "aws_s3_bucket" "dr_backup" {
  bucket = "${var.project_name}-dr-backup"
}

# Variables: use underscores, descriptive names
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

# Locals: use underscores
locals {
  common_tags = {
    Project = var.project_name
  }
}
```

**Best Practices:**
- ✅ Use variables for all configurable values
- ✅ Add descriptions to all variables
- ✅ Use `locals` for computed values
- ✅ Tag all resources
- ✅ Use `count` or `for_each` for repeated resources
- ✅ Document complex logic with comments
- ❌ Don't hardcode values
- ❌ Don't use deprecated resources
- ❌ Avoid overly complex expressions

### Python Standards

Follow PEP 8 style guide:

```python
# Good
def check_rds_status(instance_id: str) -> dict:
    """
    Check RDS instance status.
    
    Args:
        instance_id: RDS instance identifier
        
    Returns:
        dict: Instance status information
    """
    client = boto3.client('rds')
    response = client.describe_db_instances(
        DBInstanceIdentifier=instance_id
    )
    return response['DBInstances'][0]


# Bad
def checkRDSStatus(id):
    client=boto3.client('rds')
    return client.describe_db_instances(DBInstanceIdentifier=id)['DBInstances'][0]
```

**Best Practices:**
- ✅ Use type hints
- ✅ Write docstrings
- ✅ Handle exceptions
- ✅ Use meaningful variable names
- ✅ Keep functions small and focused
- ❌ Don't use global variables
- ❌ Don't ignore exceptions
- ❌ Avoid deeply nested code

### Documentation Standards

**README Structure:**
```markdown
# Module Name

Brief description of what the module does.

## Usage

```hcl
module "example" {
  source = "./modules/example"
  
  project_name = "myproject"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | S3 bucket ID |
```

---

## 📝 Commit Guidelines

### Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Maintenance tasks

**Examples:**

```bash
# Feature
git commit -m "feat(rds): add support for PostgreSQL read replicas"

# Bug fix
git commit -m "fix(s3): resolve replication configuration error"

# Documentation
git commit -m "docs(readme): update deployment instructions"

# Breaking change
git commit -m "feat(vpc)!: change default CIDR block

BREAKING CHANGE: Default VPC CIDR changed from 10.0.0.0/16 to 172.16.0.0/16"
```

**Good Commit Messages:**
- ✅ "feat(lambda): add automated failover for RDS"
- ✅ "fix(monitoring): correct CloudWatch alarm threshold"
- ✅ "docs(security): add KMS key rotation instructions"

**Bad Commit Messages:**
- ❌ "update files"
- ❌ "fix bug"
- ❌ "changes"
- ❌ "wip"

---

## 🔀 Pull Request Process

### Before Submitting

**Checklist:**
- [ ] Code follows project style guidelines
- [ ] Self-review of code completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests added/updated (if applicable)
- [ ] `terraform fmt` run successfully
- [ ] `terraform validate` passes
- [ ] Commits follow commit message guidelines

### PR Template

```markdown
## Description
Brief description of changes.

## Type of Change
- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Breaking change
- [ ] Documentation update

## How Has This Been Tested?
Describe the tests you ran.

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added
- [ ] Documentation updated
- [ ] No new warnings
- [ ] Tests added/updated

## Related Issues
Closes #123
```

### Review Process

1. **Automated Checks:**
   - CI/CD pipeline runs
   - Terraform validation
   - Linting checks

2. **Code Review:**
   - At least one maintainer approval required
   - Address all review comments
   - Update PR if requested

3. **Merge:**
   - Squash and merge (typically)
   - Delete branch after merge

---

## 🧪 Testing

### Manual Testing

```bash
# 1. Validate Terraform syntax
terraform validate

# 2. Check formatting
terraform fmt -check -recursive

# 3. Plan deployment (dev environment)
terraform plan -var-file=dev.tfvars

# 4. Apply to test account
terraform apply -var-file=dev.tfvars -auto-approve

# 5. Run DR readiness check
cd scripts
python3 dr_readiness_check.py

# 6. Test failover (dry run)
aws lambda invoke \
  --function-name test-failover \
  --payload '{"dry_run": true}' \
  response.json

# 7. Destroy test resources
terraform destroy -var-file=dev.tfvars -auto-approve
```

### Test Environments

- **Dev:** Quick testing, minimal resources
- **Staging:** Full DR setup, matches production
- **Production:** Real workloads, requires approval

---

## 🙋 Questions?

- **GitHub Issues:** For bugs and features
- **GitHub Discussions:** For questions and ideas
- **Email:** [maintainers email]

---

## 🎉 Recognition

Contributors will be:
- Added to CONTRIBUTORS.md
- Mentioned in release notes
- Credited in project documentation

Thank you for contributing! 🚀

