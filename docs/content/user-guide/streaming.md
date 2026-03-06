+++
title = "Streaming"
description = "Stream responses from the model in real time"
weight = 3
+++

## Overview

Streaming lets you process the model's response incrementally as it's generated, rather than waiting for the full response. This is useful for displaying text in real time or processing long outputs efficiently.

## Basic Streaming

Use the `stream` method with a block that receives each text chunk:

```crystal
session = Fm::Session.new(model, instructions: "You are a storyteller.")

session.stream("Tell me a short story.") do |chunk|
  print chunk
  STDOUT.flush
end
puts
```

Each `chunk` is a `String` containing the next piece of generated text.

## Streaming with Options

Pass `GenerationOptions` to control temperature and other parameters:

```crystal
options = Fm::GenerationOptions.new(
  temperature: 1.2,
  max_response_tokens: 1000_u32
)

session.stream("Write a creative poem.", options) do |chunk|
  print chunk
  STDOUT.flush
end
puts
```

## Streaming JSON

Stream structured JSON output matching a schema:

```crystal
schema = %({"type":"object","properties":{"title":{"type":"string"},"summary":{"type":"string"}},"required":["title","summary"]})

session.stream_json("Summarize the Crystal language.", schema) do |chunk|
  print chunk
  STDOUT.flush
end
puts
```

## Cancellation

Cancel an ongoing stream from another fiber:

```crystal
# Start streaming in a separate fiber
spawn do
  session.stream("Write a very long essay.") do |chunk|
    print chunk
  end
end

# Cancel after some time
sleep 2.seconds
session.cancel
```

## Checking State

Check whether the session is currently generating:

```crystal
if session.responding?
  puts "Generation in progress..."
end
```
