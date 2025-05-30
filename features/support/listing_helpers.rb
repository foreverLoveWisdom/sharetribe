module ListingHelpers

  def create_listing(shape:, community: nil, opts: {})
    community ||= @current_community

    shape_opts = {
      transaction_process_id: shape[:transaction_process_id],
      shape_name_tr_key: shape[:name_tr_key],
      action_button_tr_key: shape[:action_button_tr_key],
      listing_shape_id: shape[:id]
    }

    listing_opts = shape_opts.merge(opts).merge(community_id: community.id)

    @listing = FactoryBot.create(:listing, listing_opts)
  end

  def find_shape(name:, community: nil)
    community ||= @current_community
    # all_translations = TranslationService::API::API.translations.get(community.id)[:data]
    all_translations = CommunityTranslation.where(community_id: community.id)
                                           .pluck(:translation, :translation_key)
                                           .map{ |a| {translation: a[0], translation_key: a[1]} }
    all_shapes.find { |shape|
      all_translations.any? { |tr|
        tr[:translation_key] == shape[:name_tr_key] && tr[:translation] == name
      }
    }
  end

  def all_shapes(community: nil)
    community ||= @current_community
    community.reload.shapes
  end

end

World(ListingHelpers)
