# Paper-Trail: Shared Memory for LLMs

This is the **brain** of Antimony Labs - a shared memory system where Claude, Codex, and any other LLM can coordinate work.

## Files

- **SHARED_MEMORY.json** - Current state, active tasks, projects, infrastructure
- **schema.sql** - Original database schema
- **console-schema.sql** - Console database schema

## How to Use

### For LLMs (Claude/Codex)

1. **Read state first**: Always read `SHARED_MEMORY.json` to understand current context
2. **Pick a task**: Select from `active_tasks` list
3. **Update status**: Mark task as `in_progress` and update `last_llm` field
4. **Complete work**: When done, mark as `completed` and log progress
5. **Add context**: Update `key_decisions` or `next_steps` as needed

### For Humans

- This directory shows what the LLMs are working on
- All decisions and progress are logged here
- Open source and transparent by design

## Session Recovery

If a session ends, the next LLM (Claude or Codex) can:
```bash
cat /root/antimony-labs/paper-trail/SHARED_MEMORY.json
```

This gives full context to continue work seamlessly.

## Update Protocol

When updating SHARED_MEMORY.json:
1. Update `last_updated` timestamp
2. Update `last_llm` to your name (claude/codex)
3. Update `current_context` with what you're doing
4. Update relevant project/task status
5. Add to `key_decisions` if making important choices
