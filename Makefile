links=stories newsflashes audio-stops artstories

stories: import/wordpress.xml
	node import/stories.js | jq -I -c -r '.objectIds, .' > stories

newsflashes:
	curl 'http://newsflash.dx.artsmia.org/index.json' | jq -I -r -c '.object, .' > newsflashes

audio-stops:
	curl --silent https://raw.githubusercontent.com/artsmia/audio-stops/master/stops.min.json \
	| jq -c -r 'to_entries | map(.value) | .[] | .object_id, {title: .title, link: ("http://audio-tours.s3.amazonaws.com/"+.media_url)}' \
	> audio-stops

artstories:
	curl --silent http://griot.artsmia.org/griot/ \
	| jq -I -c -r '.objects | .[] | .id, {title: .title, description: .description, link: ("http://artsmia.github.io/griot/#/o/"+.id)}' \
	> artstories

redis:
	@for links in $(links); do \
		cat $$links | fish -c 'while read ids; read json; set -l ids (echo $$ids | tr " " "\n"); for id in $$ids; echo $$id; redis-cli sadd object:$$id:links $$json > /dev/null; end; end'; true; \
	done
# `fish -c` is terrible, but bash loses `"\""` quote escapes, which makes the `$$json` echoed into redis invalid
