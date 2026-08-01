#!/usr/bin/env python3
"""
Undermountain campaign Discord bot.
Slash commands: /session, /threads, /npc, /location, /item, /ask
"""
import os
import re
import discord
from discord import app_commands
from discord.ext import commands
from pathlib import Path
import anthropic

DATA_DIR = Path(os.environ.get("DATA_DIR", "/app/data"))
WIKI_DIR = DATA_DIR / "wiki"
SESSIONS_DIR = DATA_DIR / "sessions"

TOKEN = os.environ["DISCORD_TOKEN"]
GUILD_ID = int(os.environ.get("DISCORD_GUILD_ID", "0"))
ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY")

ai = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)


def latest_session_dir():
    dirs = sorted(
        d for d in SESSIONS_DIR.iterdir()
        if d.is_dir() and (d / "session_notes.md").exists()
    )
    return dirs[-1] if dirs else None


def trim(text, limit=4000):
    if len(text) <= limit:
        return text
    return text[: limit - 3] + "…"


def strip_frontmatter(text):
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            return text[end + 4:].strip()
    return text.strip()


def fmt_date(date_str):
    from datetime import datetime
    try:
        return datetime.strptime(date_str, "%Y-%m-%d").strftime("%B %-d, %Y")
    except Exception:
        return date_str


intents = discord.Intents.default()
bot = commands.Bot(command_prefix="!", intents=intents)


@bot.event
async def on_ready():
    print(f"Meepo online as {bot.user}", flush=True)
    await bot.change_presence(activity=discord.Game(name="Undermountain"))
    try:
        if GUILD_ID:
            guild = discord.Object(id=GUILD_ID)
            bot.tree.copy_global_to(guild=guild)
            synced = await bot.tree.sync(guild=guild)
        else:
            synced = await bot.tree.sync()
        print(f"Synced {len(synced)} slash commands", flush=True)
    except Exception as e:
        print(f"Sync failed: {e}", flush=True)


@bot.tree.command(name="session", description="Show a session summary")
@app_commands.describe(date="Session date YYYY-MM-DD (omit for latest)")
async def session_cmd(interaction: discord.Interaction, date: str = None):
    await interaction.response.defer()
    session_dir = SESSIONS_DIR / date if date else latest_session_dir()
    if not session_dir or not (session_dir / "session_notes.md").exists():
        await interaction.followup.send("Session not found.")
        return

    text = (session_dir / "session_notes.md").read_text(encoding="utf-8")
    part1 = re.split(r"═+\s*\nPART 2", text, maxsplit=1)[0].strip()

    embed = discord.Embed(
        title=f"Session — {fmt_date(session_dir.name)}",
        description=trim(part1),
        color=0x5865F2,
    )
    await interaction.followup.send(embed=embed)


@bot.tree.command(name="threads", description="Show open campaign hooks and unresolved threads")
async def threads_cmd(interaction: discord.Interaction):
    await interaction.response.defer()
    path = WIKI_DIR / "Open Threads.md"
    if not path.exists():
        await interaction.followup.send("No open threads file found — run the wiki extractor first.")
        return
    text = strip_frontmatter(path.read_text(encoding="utf-8"))
    embed = discord.Embed(title="Open Threads", description=trim(text), color=0xE67E22)
    await interaction.followup.send(embed=embed)


def _find_wiki_page(folder: str, query: str):
    directory = WIKI_DIR / folder
    if not directory.exists():
        return None, None
    slug = query.lower().replace(" ", "-")
    # Exact slug match first
    exact = directory / f"{slug}.md"
    if exact.exists():
        return exact, exact.stem
    # Partial match on filename
    for f in sorted(directory.glob("*.md")):
        if slug in f.stem:
            return f, f.stem
    # Partial match in first 300 chars (display name in title line)
    for f in sorted(directory.glob("*.md")):
        snippet = f.read_text(encoding="utf-8")[:300].lower()
        if query.lower() in snippet:
            return f, f.stem
    return None, None


@bot.tree.command(name="npc", description="Look up an NPC from the campaign wiki")
@app_commands.describe(name="NPC name (partial match OK)")
async def npc_cmd(interaction: discord.Interaction, name: str):
    await interaction.response.defer()
    path, slug = _find_wiki_page("npcs", name)
    if not path:
        await interaction.followup.send(f"No NPC matching **{name}** found.")
        return
    text = strip_frontmatter(path.read_text(encoding="utf-8"))
    embed = discord.Embed(
        title=slug.replace("-", " ").title(),
        description=trim(text),
        color=0x2ECC71,
    )
    await interaction.followup.send(embed=embed)


@bot.tree.command(name="location", description="Look up a location from the campaign wiki")
@app_commands.describe(name="Location name (partial match OK)")
async def location_cmd(interaction: discord.Interaction, name: str):
    await interaction.response.defer()
    path, slug = _find_wiki_page("locations", name)
    if not path:
        await interaction.followup.send(f"No location matching **{name}** found.")
        return
    text = strip_frontmatter(path.read_text(encoding="utf-8"))
    embed = discord.Embed(
        title=slug.replace("-", " ").title(),
        description=trim(text),
        color=0xE74C3C,
    )
    await interaction.followup.send(embed=embed)


@bot.tree.command(name="item", description="Look up an item from the campaign wiki")
@app_commands.describe(name="Item name (partial match OK)")
async def item_cmd(interaction: discord.Interaction, name: str):
    await interaction.response.defer()
    path, slug = _find_wiki_page("items", name)
    if not path:
        await interaction.followup.send(f"No item matching **{name}** found.")
        return
    text = strip_frontmatter(path.read_text(encoding="utf-8"))
    embed = discord.Embed(
        title=slug.replace("-", " ").title(),
        description=trim(text),
        color=0xF39C12,
    )
    await interaction.followup.send(embed=embed)


@bot.tree.command(name="ask", description="Ask anything about the Undermountain campaign")
@app_commands.describe(question="Your question")
async def ask_cmd(interaction: discord.Interaction, question: str):
    await interaction.response.defer()

    context_parts = []
    for fname in ["Timeline.md", "Open Threads.md", "Campaign Home.md"]:
        p = WIKI_DIR / fname
        if p.exists():
            context_parts.append(f"=== {fname} ===\n" + p.read_text(encoding="utf-8")[:2000])

    npc_dir = WIKI_DIR / "npcs"
    if npc_dir.exists():
        for f in sorted(npc_dir.glob("*.md"))[:15]:
            context_parts.append(f.read_text(encoding="utf-8")[:400])

    context = "\n\n".join(context_parts)

    resp = ai.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=800,
        messages=[{
            "role": "user",
            "content": (
                "You are a helpful assistant for the Undermountain D&D campaign. "
                "Answer concisely based on the campaign data provided.\n\n"
                f"Question: {question}\n\nCAMPAIGN DATA:\n{context}"
            ),
        }],
    )

    answer = resp.content[0].text
    embed = discord.Embed(
        title=f"Q: {question[:200]}",
        description=trim(answer),
        color=0x9B59B6,
    )
    await interaction.followup.send(embed=embed)


bot.run(TOKEN)
