# Feature Development Workflow Rules

## Starting a New Feature

1. **Clear TestLog**: Before beginning a new feature, clear `context/TestLog.md`
2. **Create a Plan**: Always produce a checklist which you progressively check off
3. **Use CurrentStory**: Every coding task should begin by using `CurrentStoryTemplate.md` to populate `CurrentStory.md` appropriately with the current task details, plan, and progress tracking

## During Development

- When implementing new features or making significant architectural changes, proactively update relevant sections of the root CLAUDE.md file
- Document new test patterns or mock requirements when adding tests
- Update command sections if new development commands are introduced
- Always make sure code is compiling successfully before reporting completeness
- Sometimes, it is acceptable for some tests to be in a broken state. But for tests that are expected to be passing, ensure they are still passing

## Completing a Feature

At the end, run all tests and add a summary of results for all tests in `context/TestLog.md`. Distinguish between:
- Tests that should fail
- Tests that shouldn't fail
- Passing tests

Format: Only the test name, status (Pass or Fail) and reason. No stack dumps or debug output of any kind.

## Conventions

- When asked to look at a markdown file, if someone says "do" or "execute" an item on a list, it means do the programming task it describes
- If a markdown file is mentioned without giving a location, look first in context/ and then in the root of this project