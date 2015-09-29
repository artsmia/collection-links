links=stories newsflashes audio-stops artstories listen 3dmodels

stories: import/wordpress.xml
	node import/stories.js | jq -s -c -r '.[] | .[] | .objectIds, (. + {type: "mia-story"} )' > stories

newsflashes:
	curl 'http://newsflash.dx.artsmia.org/index.json' | jq -s -r -c '.[] | reverse | .[] | .object, (. + {type: "newsflash"} )' > newsflashes

audio-stops:
	curl --silent https://raw.githubusercontent.com/artsmia/audio-stops/master/stops.min.json \
	| jq -c -r 'to_entries | map(.value) | .[] | .object_id, {title: .title, link: ("http://audio-tours.s3.amazonaws.com/"+.media_url), type: "audio"}' \
	> audio-stops

artstories:
	curl --silent http://new.artsmia.org/crashpad/griot/ \
	| jq -c -r '.objects | .[] | .id, {title: .title, description: .description, link: ("http://artstories.artsmia.org/#/o/"+.id), type: "artstory"}' \
	> artstories

3dmodels:
	curl --silent 'http://www.thingiverse.com/rss/user:343731' \
	| xml2json \
	| jq -c -r '.rss.channel.item[] | .title, .link' \
	| while read title; do \
	  read link; \
		id=$$(curl --silent  $$link | grep 'page=detail' | head -1 | cut -d'=' -f3 | tr -d ' '); \
		jq -n --arg title "$$title" --arg link "$$link" --arg id "$$id" \
			'$$id, {title: $$title, link: $$link, id: $$id, type: "3d"}'; \
	done | jq -c -r '.' > 3dmodels

clean:
	@rm stories newsflashes audio-stops artstories 3dmodels
	redis-cli del $$(redis-cli --raw keys 'object:*:links')

all: stories newsflashes audio-stops artstories 3dmodels

redis:
	@for links in $(links); do \
		cat $$links | fish -c 'while read ids; read json; set -l ids (echo $$ids | tr " " "\n"); for id in $$ids; echo $$id; redis-cli sadd object:$$id:links $$json > /dev/null; end; end'; true; \
	done
# `fish -c` is terrible, but bash loses `"\""` quote escapes, which makes the `$$json` echoed into redis invalid

bake:
	@for link in $$(redis-cli --raw keys 'object:*:links'); do \
		id=$$(cut -d':' -f2 <<<$$link); \
		redis-cli smembers $$link | jq -s '.' > static/$$id.json; \
	done;
rebake: clean all redis

deploy:
	rsync -avz --delete static/ ubuntu@staging.artsmia.org:/var/www/art/links/
