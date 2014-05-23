links=newsflashes stories audio-stops

stories: import/wordpress.xml
	node import/stories.js | jq -I -c -r '.objectId, .' > stories

newsflashes:
	curl 'http://newsflash.dx.artsmia.org/index.json' | jq -I -r -c '.object, .' > newsflashes

audio-stops:
	curl --silent https://raw.githubusercontent.com/artsmia/audio-stops/master/stops.min.json \
	| jq -c -r 'to_entries | map(.value) | .[] | .object_id, {title: .title, link: ("http://audio-tours.s3.amazonaws.com/"+.media_url)}' \
	> audio-stops

redis:
	for links in $(links); do \
		cat $$links | fish -c 'while read id; echo $$id; read json; redis-cli sadd object:$$id:links $$json > /dev/null; end'; \
	done;
# `fish -c` is terrible, but bash loses `"\""` quote escapes, which makes the `$$json` echoed into redis invalid
