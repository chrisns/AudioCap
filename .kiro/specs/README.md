# Kiro Specs Directory

This directory contains feature specifications following the Kiro-style workflow:

**Requirements → Design → Tasks → Implementation**

## 📁 Structure

Each feature gets its own subdirectory:

```
.kiro/specs/
├── feature-name/
│   ├── requirements.md
│   ├── design.md
│   └── tasks.md
├── another-feature/
│   ├── requirements.md
│   ├── design.md
│   └── tasks.md
└── README.md (this file)
```

## 📝 File Templates

### requirements.md Template

```markdown
# Feature Name Requirements

## Problem Statement
What problem are we solving? Who has this problem?

## Functional Requirements
- [ ] Requirement 1
- [ ] Requirement 2
- [ ] Requirement 3

## Non-Functional Requirements
- Performance: 
- Security:
- Accessibility:
- Compatibility:

## Acceptance Criteria
- [ ] Criteria 1
- [ ] Criteria 2

## Dependencies
- External systems:
- Internal dependencies:

## Constraints
- Technical limitations:
- Business constraints:
- Timeline:
```

### design.md Template

```markdown
# Feature Name Design

## Architecture Overview
High-level system design and components.

## Component Breakdown
### Component 1
- Purpose:
- Interface:
- Dependencies:

### Component 2
- Purpose:
- Interface:
- Dependencies:

## Data Models
```typescript
interface ExampleModel {
  id: string;
  name: string;
  // ...
}
```

## API Interfaces
### Endpoint 1: POST /api/example
- Request:
- Response:
- Errors:

## User Flow
1. Step 1
2. Step 2
3. Step 3

## Technical Implementation Approach
- Technology choices:
- Patterns to follow:
- Libraries/frameworks:

## Security Considerations
- Authentication:
- Authorization:
- Data protection:
```

### tasks.md Template

```markdown
# Feature Name Tasks

## Task 1: Setup
- [ ] 1.1 Create project structure
- [ ] 1.2 Install dependencies
- [ ] 1.3 Configure environment

## Task 2: Backend Implementation  
- [ ] 2.1 Create data models
- [ ] 2.2 Implement API endpoints
- [ ] 2.3 Add authentication
- [ ] 2.4 Write tests

## Task 3: Frontend Implementation
- [ ] 3.1 Create UI components
- [ ] 3.2 Connect to API
- [ ] 3.3 Add form validation
- [ ] 3.4 Write tests

## Task 4: Integration & Testing
- [ ] 4.1 End-to-end testing
- [ ] 4.2 Performance testing
- [ ] 4.3 Security testing
- [ ] 4.4 Documentation

## Dependencies
- Task 2 must complete before Task 3
- Task 3.2 depends on Task 2.2

## Estimates
- Task 1: 0.5 days
- Task 2: 2 days  
- Task 3: 1.5 days
- Task 4: 1 day
- **Total: 5 days**
```

## 🔄 Workflow Process

1. **Requirements Phase**: Create detailed requirements.md
2. **Design Phase**: Create architectural design.md based on approved requirements
3. **Task Phase**: Break down design into actionable tasks.md
4. **Implementation Phase**: Execute tasks one by one

## ✅ Best Practices

- Use kebab-case for feature directory names
- Keep requirements focused and testable
- Make designs specific enough to guide implementation
- Break tasks into small, completable chunks (< 1 day each)
- Update task status as you progress: `[ ]` → `[x]`

## 📚 Examples

Look at existing feature directories in this folder for real examples of the workflow in action. 