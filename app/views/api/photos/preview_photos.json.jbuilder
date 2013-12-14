json.photos @photos do |photo|
    json.id photo.id
    json.establishment_id photo.establishment_id
    json.user_id photo.user_id
    json.thumb_url photo.image.url(:thumb)
    json.small_url photo.image.url(:small)
    json.medium_url photo.image.url(:medium)
end