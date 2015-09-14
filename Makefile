links=stories newsflashes audio-stops artstories listen

stories: import/wordpress.xml
	node import/stories.js | jq -s -c -r '.[] | .[] | .objectIds, .' > stories

newsflashes:
	curl 'http://newsflash.dx.artsmia.org/index.json' | jq -s -r -c '.[] | reverse | .[] | .object, .' > newsflashes

audio-stops:
	curl --silent https://raw.githubusercontent.com/artsmia/audio-stops/master/stops.min.json \
	| jq -c -r 'to_entries | map(.value) | .[] | .object_id, {title: .title, link: ("http://audio-tours.s3.amazonaws.com/"+.media_url)}' \
	> audio-stops

artstories:
	curl --silent http://new.artsmia.org/crashpad/griot/ \
	| jq -c -r '.objects | .[] | .id, {title: .title, description: .description, link: ("http://artstories.artsmia.org/#/o/"+.id)}' \
	> artstories

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
