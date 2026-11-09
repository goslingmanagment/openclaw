Proof media for https://github.com/openclaw/openclaw/pull/196217 (Telegram Web A, real user account, a bot created for this proof; only the bot chat is in frame).

- before-upstream-main.{png,mp4}: Gateway built from upstream/main 4b077d31b91. The agent sends Alpha/Beta through the message tool; tapping Beta removes the keyboard and replies "This action is no longer available." (model requests 4 -> 4).
- after-this-pr.{png,mp4}: Gateway built from the PR head dd7b8ad725a. Same send; tapping Beta starts an agent turn with callback_data: pick:beta and the mock model replies MODEL_SAW_CALLBACK (model requests 4 -> 5).
