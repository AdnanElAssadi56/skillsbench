FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      bcftools \
      tabix \
      python3 \
      python3-pip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /root

COPY data /root/data

# Deploy skills to every agent-framework path used by the SkillsBench harness.
# To run a without-skill baseline, comment out the four COPY lines below and rebuild.
# COPY skills /root/.claude/skills
# COPY skills /root/.codex/skills
# COPY skills /root/.opencode/skill
# COPY skills /root/.agents/skills

CMD ["/bin/bash"]
