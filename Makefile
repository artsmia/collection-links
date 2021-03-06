links=stories audio-stops artstories listen 3dmodels conservation adopt-a-painting exhibitions catalogs

stories: import/wordpress.xml
	node import/stories.js | jq -s -c -r '.[] | .[] | (. + {objectId: .objectIds, type: "mia-story"} )' > stories

newsflashes:
	curl 'http://newsflash.dx.artsmia.org/index.json' \
	| jq -s -r -c '.[] \
		| reverse | .[] | \
		(. + {objectId: .object, type: "newsflash"} ) \
	' > newsflashes

audio-stops:
	cat ../audio-stops/stops.json > /dev/null
	curl --silent https://raw.githubusercontent.com/artsmia/audio-stops/master/stops.min.json \
	| jq -c -r 'to_entries | map(.value) | .[] | {objectId: .object_id, title: .title, link: ("http://audio-tours.s3.amazonaws.com/"+.media_url), type: "audio", number: .audio_stop_number}' \
	> audio-stops

artstories:
	curl --silent http://new.artsmia.org/crashpad/griot/ \
	| jq -c -r '.objects | .[] | {title: .title, description: .description, link: ("http://artstories.artsmia.org/#/o/"+.id), type: "artstory", objectId: .id}' \
	> artstories

3dmodels-thingiverse:
	curl --silent 'http://www.thingiverse.com/rss/user:343731' \
	| xml2json \
	| jq -c -r '.rss.channel.item[]' \
	| while read -r json; do \
		description=$$(jq -c -r '.description' <<<$$json); \
		id=$$(echo $$description | pup -p 'a[href*=collections.artsmia] attr{href}' | sed 's|.*id=\([0-9]*\).*|\1|; s|.*art/\([0-9]*\).*|\1|'); \
		thumb=$$(echo $$description | pup -p 'img attr{src}'); \
		jq '.' <<<$$json | jq --arg id "$$id" --arg thumb "$$thumb" \
			'{title: .title, link: .link, objectId: $$id, type: "3d", thumb: $$thumb}'; \
	done | jq -c -r '.' | grep -v 'index.php?page=jka' > 3dmodels-thingiverse
3dmodels-sketchfab:
	curl --silent 'https://api.sketchfab.com/v2/models?user=4a165be2661d4a6a866ea01d1f76334c' \
	| jq -c '.results[]' \
	| while read -r json; do \
		id=$$(jq '.description' <<<$$json | grep artsmia.org | sed -e 's|.*artsmia.org/art/\([0-9]*\).*|\1|; s|.*artsmia.org/index.php?page=detail&id=\([0-9]*\).*|\1|'); \
		jq --arg id "$$id" '{type: "3d", title: .name, link: .viewerUrl, thumb: .thumbnails.images[4].url, objectId: $$id}' <<<$$json; \
	done | jq -c -r '.' > 3dmodels-sketchfab;

3dmodels: 3dmodels-sketchfab
	cat 3dmodels-* | jq -s -c -r 'map(select((.objectId | length) > 0)) \
		| group_by(.objectId) \
		| sort_by(.[0].objectId | tonumber) \
		| map(if (. | length) > 1 then . else .[] end) \
		| .[] \
	  ' > 3dmodels

listen:
	curl --silent https://raw.githubusercontent.com/artsmia/listen/gh-pages/audio/index.json \
	| jq -c -r 'to_entries | .[] | {title: .value.title, objectId: .value.id, link: ("http://artsmia.github.io/listen/#/"+.key)}' \
	> listen

adopt-a-painting:
	@curl --silent curl 'http://new.artsmia.org/collections/fetch/adopt/children/' \
	| jq -c -r 'to_entries[].value | { \
		id: .coll_adoptee_obj_id, \
		type: "adopt-a-painting", \
		adopted: .coll_adoptee_is_adopted, \
		description: .coll_adoptee_description, \
		cost: .coll_adoptee_cost \
	}' > adopt-a-painting

# These are exhibitions to use for testing out the 'rotations' idea
approvedExhibitions = " 1640 1654 1802 1803 1822 1833 1952 2155 2265 2266 2277 2281 2284 2299 2307 2324 2325 2329 2399 "
# if I only want exhibitions flagged as 'rotations' in es I can do this (v)
#
#     approvedExhibitionRegex=$$(echo $(approvedExhibitions) | sed 's/ /.json\\|/g; s/$$/.json/');
#     find … | grep $$approvedExhibitionRegex
#
# but I want them all, so I'm using a hacky string comparison to populate `rotation:`
# …though who am I kidding, this whole file is a hacky string comparison '-)
exhibitions:
	find ../collection/exhibitions -name '*.json' | xargs jq --arg rotations $(approvedExhibitions) -c -r 'select(.exhibition_id) | \
		{ \
			id: .exhibition_id, \
			title: .exhibition_title, \
			description: .exhibition_description, \
			date: .display_date, \
			objectId: .objects | map(tostring) | join(" "), \
			type: "exhibition", \
			rotation: (" " + (.exhibition_id | tostring) + " " | inside($$rotations)) \
		}' \
	> exhibitions

clean:
	@rm stories newsflashes audio-stops artstories 3dmodels
	redis-cli --raw keys 'object:*:links' | xargs redis-cli del

all: $(links)

catalogs:
	cat ../mia-catalogs/catalogs.json \
	| jq -c -r '.[] | .ids, .' \
	> $@

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
