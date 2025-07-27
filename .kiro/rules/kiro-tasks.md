Implements Kiro-style task execution workflow for systematic, reviewable development. Enforces one-task-at-a-time execution with mandatory user review between tasks. Ensures traceability and prevents runaway coding by requiring explicit approval before each implementation step.

# Kiro-Style Task Execution Workflow

## Pre-Implementation Requirements

Before starting ANY coding task:
1. **MUST** read `.kiro/specs/{feature}/requirements.md`
2. **MUST** read `.kiro/specs/{feature}/design.md` 
3. **MUST** read `.kiro/specs/{feature}/tasks.md`
4. Understand the full context and approved plan

## Task Execution Rules

### Single Task Focus
- Execute **ONLY ONE TASK** at a time
- Start with the first uncompleted task `[ ]` in tasks.md
- Focus on subtasks before moving to main tasks
- Complete the ENTIRE task before stopping

### Implementation Process
1. **Read** the specific task requirements
2. **Implement** the complete solution for that task
3. **Test** the implementation works correctly
4. **CRITICAL: Run ALL tests** - tests MUST pass before task completion
5. **Mark complete** by changing `[ ]` to `[x]` in tasks.md
6. **STOP** and report completion
7. **Ask for review** before proceeding to next task

### Mandatory Stop Points
After completing each task:
- **ALWAYS** stop and summarize what was completed
- **ALWAYS** mark the task as `[x]` in tasks.md
- **ALWAYS** ask: "Task completed. Please review and let me know if I should proceed to the next task."
- **NEVER** continue to next task without explicit approval

### Task Completion Criteria
A task is complete when:
- All functionality described in the task is working
- Code follows project standards and conventions
- **ALL TESTS PASS** - this is mandatory and non-negotiable
- No errors or warnings in implementation
- Task is marked `[x]` in tasks.md file

**CRITICAL TEST REQUIREMENT**: Tests must ALWAYS pass before considering ANY task complete. If tests fail:
1. Fix all failing tests immediately
2. Do not mark task as complete until ALL tests pass
3. Do not proceed to next task until ALL tests pass
4. This applies to unit tests, integration tests, and all test suites

## Task Interaction Patterns

### Starting Work
```
"I'll now work on Task 1.1: [task description]. 
Based on the requirements and design docs, I'll implement [brief plan]."
```

### Completing Work  
```
"✅ Task 1.1 completed: [brief summary of what was done]
- [specific changes made]
- [files modified]
- ✅ ALL TESTS PASSING
- Marked as complete in tasks.md

Please review and let me know if I should proceed to Task 1.2."
```

### Error Handling
If issues arise:
- Document the problem clearly
- Propose solution approaches
- Ask for guidance before proceeding
- Update tasks.md with any discovered dependencies

## File Management

### Updating tasks.md
- Mark completed tasks: `[x] Task description`
- Keep incomplete tasks: `[ ] Task description`  
- Add discovered subtasks when needed
- Maintain original task structure and numbering

### Progress Tracking
- Always update the task status in tasks.md
- Include brief completion notes if helpful
- Preserve the original task descriptions

## Examples

<example>
Good Task Execution:
1. Read requirements.md, design.md, tasks.md
2. Start Task 1.1: "Set up database schema"
3. Implement complete database schema
4. Test schema creation works
5. **Run all tests and ensure they pass**
6. Mark `[x] 1.1 Set up database schema` in tasks.md
7. Stop and ask: "Task 1.1 completed. Schema is working correctly and all tests pass. Please review and let me know if I should proceed to Task 1.2."
</example>

<example type="invalid">
Poor Task Execution:
1. Start implementing multiple tasks simultaneously
2. Complete task but don't update tasks.md
3. Continue to next task without asking for review
4. Make changes beyond the scope of current task
5. **Mark task complete while tests are failing**
[WRONG: Violated single-task focus, review requirements, and critical test requirements]
</example>

## User Approval Responses

Continue to next task when user says:
- ✅ "looks good, continue" / "proceed" / "next task"
- ✅ "approved" / "yes" / "go ahead"

Stop and clarify when user says:
- ❌ "wait" / "hold on" / "let me check"
- ❌ "make changes" / "fix this first" 
- ❌ No response or unclear feedback

## Context Preservation

- Always reference the original spec documents
- Stay aligned with approved requirements and design
- Raise concerns if tasks seem inconsistent with specs
- Suggest spec updates if new requirements emerge 