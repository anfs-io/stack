# Gemstash

RubyGems caching mirror and private gem server, from the rubygems org
(<https://github.com/rubygems/gemstash>). Bundler fetches through it, so it caches
every gem from rubygems.org, and you can `gem push` private gems to it.

There's no official image, so `pcm up` builds `localhost/pcm-gemstash:<version>`
from [`Containerfile`](./Containerfile) the first time it runs. Storage is sqlite
plus gem files under `~/.local/share/pcm/volumes/gemstash`.

## Run

```sh
pcm up gemstash
pcm down gemstash
podman compose --pcm logs -f gemstash
curl localhost:9292/health
```

## Use as a mirror

```sh
bundle config set --global mirror.https://rubygems.org http://localhost:9292
# undo: bundle config unset --global mirror.https://rubygems.org
```

## Private gems

Create an API key:

```sh
podman exec -it gemstash_gemstash_1 gemstash authorize        # all permissions
podman exec -it gemstash_gemstash_1 gemstash authorize push yank
```

Push with it:

```sh
# ~/.gem/credentials:  :gemstash: <key>
gem push --key gemstash --host http://localhost:9292/private my_gem-0.1.0.gem
```

Consume from a Gemfile:

```ruby
source "http://localhost:9292/private" do
  gem "my_gem"
end
```

When `GEMSTASH_PROTECTED_FETCH=true`, downloading private gems also needs a key
(`gemstash authorize fetch`), which you configure with
`bundle config set http://localhost:9292/private/ <key>`.

## Configuration

Tunables and defaults live in [`.env.schema`](./.env.schema). They're passed
into the container and rendered by [`config.yml.erb`](./config.yml.erb).
To change the gemstash version, set `GEMSTASH_VERSION`. The next `pcm up`
builds a new image.
