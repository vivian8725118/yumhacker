json.current_page @listings.current_page
json.per_page @listings.limit_value
json.total_pages @listings.total_pages
json.offset @listings.offset_value
json.total @listings.total_count

json.listings @listings do |listing|
    json.id listing.id
    json.list_id listing.list_id
    json.path listing.establishment.path
    json.establishment_id listing.establishment.id
    json.name listing.establishment.name
    json.street_number listing.establishment.street_number
    json.street listing.establishment.street
    json.city listing.establishment.city
    json.state listing.establishment.state
    json.lat listing.establishment.latlng.lat
    json.lng listing.establishment.latlng.lon

    unless listing.comments.empty? 
        json.comment do 
            comment = listing.comments.first
            json.id comment.id
            json.body comment.body
            json.updated_at comment.updated_at
        end
    end

    json.categories listing.establishment.categories do |category|
        json.name category.name
        json.id category.id
    end

    json.wish_list_id current_user.try(:wish_lists).try(:first).try(:id)
    json.wish_listed current_user ? current_user.wish_listed?(listing.establishment.id) : false
end