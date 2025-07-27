# Kiro Workflow Setup for Cursor

## Overview

This setup transforms Cursor into a Kiro-like spec-driven development environment. The system enforces a disciplined workflow: **Requirements → Design → Tasks → Implementation** with mandatory user approval at each stage.

## 🚀 Quick Start

### 1. Files Created
- `.cursor/rules/kiro-spec.mdc` - Specification workflow rules
- `.cursor/rules/kiro-tasks.mdc` - Task execution rules  
- `.kiro/specs/` - Directory for storing specifications

### 2. Cursor Settings (Recommended)

Add this to your Cursor settings to properly view `.mdc` files:

```json
{
  "workbench.editorAssociations": {
    "*.mdc": "default"
  }
}
```

### 3. Usage Workflow

## 📋 Complete Workflow Guide

### Phase 1: Feature Planning (Spec Mode)

**Start a new feature:**
```
"Add user authentication system"
```

**What happens:**
1. ✅ Cursor creates `.kiro/specs/user-authentication/requirements.md`
2. ✅ Stops and asks: "Do the requirements look good? Any changes needed before proceeding to design?"
3. ⏸️ **YOU MUST APPROVE** before continuing

**Your response options:**
- `"looks good"` → Proceeds to design phase
- `"make these changes: [specific feedback]"` → Updates requirements
- `"wait"` → Stops workflow

### Phase 2: Design (Still Spec Mode)

**After requirements approval:**
1. ✅ Cursor creates `.kiro/specs/user-authentication/design.md`
2. ✅ Stops and asks: "Does the design look good? Any changes needed before creating tasks?"
3. ⏸️ **YOU MUST APPROVE** before continuing

### Phase 3: Task Planning (Still Spec Mode)

**After design approval:**
1. ✅ Cursor creates `.kiro/specs/user-authentication/tasks.md`
2. ✅ Stops and asks: "Do the tasks look good? Ready to begin implementation?"
3. ⏸️ **YOU MUST APPROVE** before starting implementation

### Phase 4: Implementation (Task Mode)

**Switch to task execution mode:**
```
"Execute Task 1.1 from the user-authentication spec"
```

**What happens:**
1. ✅ Cursor reads all three spec files for context
2. ✅ Implements ONLY the specified task
3. ✅ Marks task complete `[x]` in tasks.md
4. ✅ Stops and asks: "Task completed. Please review and let me know if I should proceed to the next task."
5. ⏸️ **YOU MUST APPROVE** before continuing to next task

## 🎯 Custom Chat Modes (Optional but Recommended)

### Create Spec Mode
1. Open Cursor Settings → Chat Modes
2. Create new mode:
   - **Name**: "Spec Mode"
   - **Base prompt**: "Follow kiro-spec.mdc rules to plan this feature systematically."
   - **Tools**: Edit only
   - **Keybinding**: `Cmd+Shift+S`

### Create Task Mode  
1. Create another mode:
   - **Name**: "Task Mode"
   - **Base prompt**: "Follow kiro-tasks.mdc rules to execute tasks one at a time."
   - **Tools**: Edit & Run
   - **Keybinding**: `Cmd+Shift+T`

## 📁 File Structure

Your project will have this structure:

```
your-project/
├── .cursor/
│   └── rules/
│       ├── kiro-spec.mdc
│       └── kiro-tasks.mdc
├── .kiro/
│   └── specs/
│       └── {feature-name}/
│           ├── requirements.md
│           ├── design.md
│           └── tasks.md
└── [your project files]
```

## 🔄 Example Complete Workflow

### 1. Start Feature Planning
```
You: "Add a REST API for user management"

Cursor: Creates requirements.md and stops
"Do the requirements look good? Any changes needed before proceeding to design?"

You: "looks good"

Cursor: Creates design.md and stops  
"Does the design look good? Any changes needed before creating tasks?"

You: "looks good"

Cursor: Creates tasks.md and stops
"Do the tasks look good? Ready to begin implementation?"

You: "yes, let's start"
```

### 2. Execute Tasks
```
You: "Execute Task 1.1 from the user-management spec"

Cursor: Implements the task and stops
"✅ Task 1.1 completed: Created user model and database schema
- Created models/User.ts
- Created database migrations
- Marked as complete in tasks.md

Please review and let me know if I should proceed to Task 1.2."

You: "proceed"

[Continues task by task...]
```

## ⚡ Key Benefits

1. **No More "Vibe Coding"** - Every feature follows a structured plan
2. **Explicit Control** - You approve every major step
3. **Traceability** - Complete documentation of decisions and progress  
4. **Focused Implementation** - One task at a time prevents scope creep
5. **Persistent Memory** - Specs survive across sessions

## 🎛️ Advanced Usage

### Multiple Features in Parallel
- Use different folders: `.kiro/specs/feature-a/`, `.kiro/specs/feature-b/`
- Open separate Cursor tabs for each feature
- Each tab maintains its own workflow state

### Handling Changes
- Update requirements: "Update the user-auth requirements to include 2FA"
- Add tasks: "Add a new task for email verification to user-auth"
- Modify design: "Change the authentication design to use JWT tokens"

### Integration with Existing Projects
- Works with any tech stack
- Adapts to your existing file structure
- Specs complement your existing documentation

## 🚨 Important Rules to Remember

### For Spec Phase:
- ❌ **NEVER** skip approval gates
- ❌ **NEVER** combine phases (no requirements+design+tasks at once)
- ✅ **ALWAYS** wait for your explicit approval

### For Task Phase:  
- ❌ **NEVER** work on multiple tasks simultaneously
- ❌ **NEVER** continue without approval
- ✅ **ALWAYS** mark tasks complete in tasks.md
- ✅ **ALWAYS** ask for review after each task

## 🔧 Troubleshooting

### "Cursor isn't following the workflow"
- Make sure `.mdc` files are in `.cursor/rules/`
- Check that frontmatter is properly formatted
- Try restarting Cursor to reload rules

### "Tasks not being marked complete"
- Verify `tasks.md` exists in the correct location
- Check that task format uses `[ ]` and `[x]` checkboxes

### "Workflow seems too rigid"
- This is intentional! The structure prevents chaos
- You can always override by being specific: "Skip approval and proceed to design"
- Remember: you can exit the workflow anytime for quick fixes

## 🎉 Next Steps

1. Try creating your first feature using this workflow
2. Experiment with both Spec Mode and Task Mode
3. Adapt the rules to your specific needs
4. Share feedback and improvements with the community

The goal is to bring Kiro's disciplined, spec-driven approach to Cursor while maintaining the flexibility and power you're used to! 