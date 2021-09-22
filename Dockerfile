# Use an official Elixir runtime as a parent image
FROM elixir:latest

RUN apt-get update && \
    mix local.hex --force && \
    mix local.rebar --force

# Create app directory and copy the Elixir projects into it
RUN mkdir /app
COPY . /app
WORKDIR /app

# RUN cd assets && npm install
# Install hex package manager
RUN mix local.hex --force

# Compile the project
RUN mix deps.get