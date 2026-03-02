# Contributing to NTARI OS

Thank you for your interest in contributing to NTARI OS! This project represents a paradigm shift toward cooperative, democratic computing infrastructure.

## Getting Started

### Prerequisites

- **For Core Development**: Alpine Linux environment, Docker
- **For Installer Development**: Node.js 18+, npm
- **For Documentation**: Markdown editor, basic git knowledge

### Development Setup

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR-USERNAME/ntari-os.git
   cd ntari-os
   ```

2. **Set up upstream remote**
   ```bash
   git remote add upstream https://github.com/ntari/ntari-os.git
   ```

3. **Install dependencies**
   ```bash
   # For installer development
   cd installer
   npm install

   # For core system (requires Alpine Linux or Docker)
   cd core
   ./setup-dev.sh
   ```

## How to Contribute

### 1. Code Contributions

**Areas needing help**:
- USB installer improvements
- Desktop environment customization
- Mobile app development
- Network layer optimization
- Documentation translation

**Process**:
1. Check existing [Issues](https://github.com/ntari/ntari-os/issues)
2. Comment on issue you want to work on
3. Create feature branch: `git checkout -b feature/your-feature-name`
4. Make changes
5. Test thoroughly
6. Submit Pull Request

### 2. Documentation

We need help with:
- Installation guides in multiple languages
- Video tutorials
- BIOS boot screen photos
- Troubleshooting guides
- API documentation

### 3. Testing

- Test installations on various hardware
- Report bugs with detailed steps to reproduce
- Test USB installer on different platforms
- Verify network discovery on different networks

### 4. Community Support

- Answer questions on Discord/Forum
- Help at installation parties
- Create tutorials and guides
- Share your NTARI experience

## Code Standards

### General Guidelines

- **Philosophy First**: Changes must align with NTARI principles
  - No extraction
  - Mutual benefit
  - Democratic governance
  - Privacy by design

- **Code Quality**:
  - Clear, commented code
  - Follow existing patterns
  - Write tests for new features
  - Update documentation

### Language-Specific

**Python**:
- Follow PEP 8
- Use type hints
- Write docstrings

**JavaScript/React**:
- Use ESLint configuration
- Functional components with hooks
- PropTypes for components

**Shell Scripts**:
- POSIX-compliant when possible
- Clear variable names
- Comment complex sections

**Rust**:
- Follow Rust conventions
- Run `cargo fmt` and `cargo clippy`
- Write unit tests

## Commit Messages

Use clear, descriptive commit messages:

```
[component] Brief description

Longer explanation if needed. Explain WHY, not just WHAT.

Fixes #123
```

**Examples**:
- `[installer] Add macOS USB detection support`
- `[core] Optimize Alpine package list for size`
- `[docs] Add Spanish installation guide`
- `[network] Fix peer discovery timeout issue`

## Pull Request Process

1. **Before submitting**:
   - Ensure code follows standards
   - Run tests: `npm test` or `pytest`
   - Update documentation
   - Rebase on latest main: `git rebase upstream/main`

2. **PR Description**:
   ```markdown
   ## What does this PR do?
   Brief explanation

   ## Why?
   Reasoning behind the change

   ## Testing
   How you tested it

   ## Checklist
   - [ ] Tests pass
   - [ ] Documentation updated
   - [ ] Follows code standards
   - [ ] Tested on target platforms
   ```

3. **Review Process**:
   - Core team reviews within 3 days
   - Address feedback
   - Maintain respectful discussion
   - Once approved, we'll merge

## Roadmap & Priorities

See [ROADMAP.md](./ROADMAP.md) for development priorities.

**Current focus (Phase 1)**:
- Alpine Linux base system
- USB installer tool
- Desktop environment
- First-run wizard

## Communication

- **Discord**: [discord.gg/ntari](https://discord.gg/ntari)
  - #development - General dev discussion
  - #installer - USB installer specific
  - #core-system - Base system development
  - #mobile - Android/iOS apps

- **Forum**: [community.ntari.org](https://community.ntari.org)
  - Longer-form technical discussions
  - Architecture decisions
  - RFCs (Request for Comments)

- **GitHub Issues**: Bug reports, feature requests
- **Email**: info@ntari.org for private matters

## Code of Conduct

### Our Pledge

We are committed to making participation in NTARI a harassment-free experience for everyone, regardless of:
- Age, body size, disability, ethnicity
- Gender identity and expression
- Level of experience
- Nationality, personal appearance, race
- Religion, sexual identity and orientation

### Our Standards

**Positive behavior**:
- Using welcoming, inclusive language
- Respecting differing viewpoints
- Accepting constructive criticism gracefully
- Focusing on what's best for the community
- Showing empathy toward others

**Unacceptable behavior**:
- Trolling, insulting/derogatory comments
- Public or private harassment
- Publishing others' private information
- Other conduct reasonably considered inappropriate

### Enforcement

Report violations to info@ntari.org. All reports reviewed confidentially.

Consequences may include:
1. Warning
2. Temporary ban
3. Permanent ban

## License

By contributing, you agree that your contributions will be licensed under the same license as NTARI OS (TBD - likely cooperative/commons-based).

## Recognition

All contributors are recognized in:
- CONTRIBUTORS.md file
- Release notes
- Annual community acknowledgment

Significant contributors may be invited to join the Core Team.

## Questions?

Don't hesitate to ask! We're here to help:
- Post in Discord #development channel
- Open a GitHub Discussion
- Email info@ntari.org

**Welcome to the NTARI community!** 🌐
