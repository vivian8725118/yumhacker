class Api::EstablishmentsController < ApplicationController
  respond_to :json
  before_filter :authenticate_user!, :only => [:create]

  include GooglePlaces

  def index
    location = params[:location]
    where = params[:where]
    client = params[:client]
    page = params[:page] || 1
    relation = where[:relation]
    categories = where[:categories] || []
    
    lat = location[:center][:lat]
    lng = location[:center][:lng]

    if location[:contained_in] == 'radius'    # Request from a point (i.e Main Search request)
      radius = location[:radius]

      if relation == 'followed' && current_user
        @establishments = Establishment.from_users_followed_by(current_user).within_radius(lat, lng, radius).by_category(categories).page(page).per(10)
      elsif relation == 'me' && current_user
        @establishments = current_user.establishments.within_radius(lat, lng, radius).by_category(categories).page(page).per(10)      
      elsif relation == 'all'
        @establishments = Establishment.within_radius(lat, lng, radius).by_category(categories).page(page).per(10)
      end
    elsif location[:contained_in] == 'bounds'    # Request from bounds (i.e. Map move)
      bounds = location[:bounds]
      xmin = bounds[:sw][:lng]
      ymin = bounds[:sw][:lat]
      xmax = bounds[:ne][:lng]
      ymax = bounds[:ne][:lat]

      if relation == 'followed' && current_user
        @establishments = Establishment.from_users_followed_by(current_user).within_bounds(xmin, ymin, xmax, ymax, lat, lng).by_category(categories).page(page).per(10)
      elsif relation == 'me' && current_user
        @establishments = current_user.establishments.within_bounds(xmin, ymin, xmax, ymax, lat, lng).by_category(categories).page(page).per(10)      
      elsif relation == 'all'
        @establishments = Establishment.within_bounds(xmin, ymin, xmax, ymax, lat, lng).by_category(categories).page(page).per(10)
      end
    end

    @endorsing_users = []
    estab_ids = @establishments.map(&:id)

    if user_signed_in? && relation != 'all'
      # get all users you're following that are endorsing those establisments
      @endorsing_users = User.includes(:establishments).where('endorsements.establishment_id IN (?)', estab_ids).references(:endorsements).joins(:reverse_relationships).where(relationships: {follower_id: current_user.id}).order('relationships.created_at DESC')
    else
      @endorsing_users = User.includes(:establishments).where('endorsements.establishment_id IN (?)', estab_ids).references(:endorsements).order('endorsements.created_at DESC')
    end
	end

  def show
    @establishment = Establishment.includes(:hours).includes(:photos).friendly.find(params[:id])
  end

  def create
    @establishment = Establishment.find_by(google_id: params[:google_id])

    unless @establishment
      @establishment = Establishment.create(name: params[:name], formatted_address: params[:formatted_address], price: params[:price], google_id: params[:google_id])
      @establishment.latlng = Establishment.rgeo_factory_for_column(:latlng, {}).point(params[:lng], params[:lat])
      @establishment.save
    end

    current_user.endorse!(@establishment.id) unless current_user.endorsing?(@establishment.id)

    # Occasionally search will return a Google result that is already in the DB
    if params[:reference] && @establishment.hours.empty?
      details = google_places_details(params[:reference])
      hours = details[:hours]
      details.delete(:hours)
      hours.each do |hour|
        @establishment.hours.create(hour)
      end
      @establishment.update_attributes(details)
      @establishment.slug = nil
      @establishment.save!
    end
  end

  def search
    query = params[:query]    
    lat = params[:lat]
    lng = params[:lng]

    if query && !query.strip.empty?
      radius = 100

      @establishments = google_places(query, lat, lng)
      wild_query = "%#{query.downcase.gsub(/\s+/, '%')}%"

      database_establishments = Establishment.where('LOWER(name) LIKE ?', wild_query).where("ST_Contains(ST_Expand(ST_geomFromText('POINT (? ?)', 4326), ?), establishments.latlng :: geometry)", lng.to_f, lat.to_f, radius.to_f * 1.0/(60 * 1.15078)).order("latlng :: geometry <-> 'SRID=4326;POINT(#{lng.to_f} #{lat.to_f})' :: geometry").limit(10)

      @establishments = database_establishments + @establishments unless database_establishments.empty?
      
      @establishments.uniq!{ |estab| estab[:google_id] }

      @establishments
    else
      render :json => []
    end
  end

  def endorsers
    page = params[:page] || 1
    @endorsers = Establishment.find(params[:establishment_id]).users.page(page).per(30)
  end
end