import discord

BOT_TOKEN = "MTUxNTY4MTQ5Nzk0MjcyMDUzMw.GRruMw._ny36kuuOgHDeKfPgGDvIH8aL4G7kdGjx_kpIo"
CHANNEL_ID = 1515684713677852783

intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)

@client.event
async def on_ready():
    print(f'✅ Бот {client.user} запущен!')

@client.event
async def on_message(message):
    if message.author.bot or message.channel.id != CHANNEL_ID:
        return
    
    if message.content.lower() == '!help':
        await message.channel.send('✅ Бот работает!')

client.run(BOT_TOKEN)
