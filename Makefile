links=stories audio-stops artstories listen 3dmodels listen conservation adopt-a-painting

stories: import/wordpress.xml
	node import/stories.js | jq -s -c -r '.[] | .[] | .objectIds, (. + {type: "mia-story"} )' > stories

newsflashes:
	curl 'http://newsflash.dx.artsmia.org/index.json' \
	| jq -s -r -c '.[] \
		| reverse | .[] | \
		.object, (. + {type: "newsflash"} ) \
	' > newsflashes

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
	| jq -c -r '.rss.channel.item[]' \
	| while read -r json; do \
		description=$$(jq '.description' <<<$$json); \
		link=$$(jq '.link' <<<$$json); \
		id=$$(grep 'id=' <<<$$description | sed 's|.*id=\([0-9]*\).*|\1|'); \
		thumb=$$(echo $$description | head -1 | sed 's|.*\(https://cdn.thingiverse.com/renders/.*jpg\).*|\1|'); \
		echo $$json | jq --arg id "$$id" --arg thumb "$$thumb" \
			'$$id, {title: .title, link: .link, id: $$id, type: "3d", thumb: $$thumb}'; \
	done | jq -c -r '.' > 3dmodels
	curl --silent 'https://api.sketchfab.com/v2/models?user=4a165be2661d4a6a866ea01d1f76334c' \
	| jq -c '.results[]' \
	| while read -r json; do \
		id=$$(jq '.description' <<<$$json | grep artsmia.org | sed -e 's|.*artsmia.org/art/\([0-9]*\).*|\1|; s|.*artsmia.org/index.php?page=detail&id=\([0-9]*\).*|\1|'); \
		jq --arg id "$$id" '$$id, {type: "3d", title: .name, link: .viewerUrl, thumb: .thumbnails.images[4].url}' <<<$$json; \
	done | jq -c -r '.' >> 3dmodels;

listen:
	curl --silent https://raw.githubusercontent.com/artsmia/listen/gh-pages/audio/index.json \
	| jq -c -r 'to_entries | .[] | .value.id, {title: .value.title, object: .value.id, link: ("http://artsmia.github.io/listen/#/"+.key)}' \
	> listen

adopt-a-painting:
	@curl --silent curl 'http://new.artsmia.org/collections/fetch/adopt/children/' \
	| jq -c -r 'to_entries[].value | .coll_adoptee_obj_id, { \
		id: .coll_adoptee_obj_id, \
		type: "adopt-a-painting", \
		adopted: .coll_adoptee_is_adopted, \
		description: .coll_adoptee_description, \
		cost: .coll_adoptee_cost \
	}' > adopt-a-painting

clean:
	@rm stories newsflashes audio-stops artstories 3dmodels
	redis-cli --raw keys 'object:*:links' | xargs redis-cli del

all: stories newsflashes audio-stops artstories 3dmodels listen

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
	rsync -avz --delete static/ collections:/var/www/art/links/

.PHONY: stories newsflashes audio-stops artstories 3dmodels listen
