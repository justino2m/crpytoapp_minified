module Api
  class ResourceController < BaseController
    before_action :load_resource

    def create
      @object.assign_attributes(permitted_params)
      @object.assign_attributes(default_params)
      @object.valid? # run validations so that default params can be set by the model
      authorize! :create, @object if respond_to? :authorize!
      @object.save
      # respond_with @object, include: default_includes
      render :ok
    end

    private

    class << self
      attr_accessor :parent_data

      def belongs_to(model_name, options = {})
        @parent_data ||= {}
        @parent_data[:model_class] = model_name.to_s.classify.constantize
        @parent_data[:model_name] = @parent_data[:model_class].model_name.param_key
        @parent_data[:find_by] = options[:find_by] || :id

        # ignored for get requests
        @parent_data[:authorize] = options[:authorize] || :update
      end
    end

    def parent_data
      self.class.parent_data
    end

    def parent
      return @parent if @parent
      @parent = parent_data[:model_class].send('find_by!', { parent_data[:find_by] => params["#{parent_data[:model_name]}_id"] })
      instance_variable_set("@#{parent_data[:model_name]}", @parent)
    end

    def load_resource
      if member_action?
        @object ||= create_action? ? build_resource : find_resource
        # authorize_resource
        instance_variable_set("@#{model_name}", @object)
      else
        @collection ||= collection
        instance_variable_set("@#{controller_name}", @collection)
      end
    end

    def build_resource
      if parent_data.present?
        parent.send(controller_name).build
      else
        model_class.new
      end
    end

    def find_resource
      if parent_data.present?
        parent.send(controller_name).find(params[:id])
      else
        model_class.find(params[:id])
      end
    end

    #########################################
    # STRONG PARAMETERS
    #########################################
    def allowed_attributes
      name = "permitted_#{model_name}_attributes"
      send(name) if respond_to?(name, true)
    end

    def allowed_create_attributes
      allowed_attributes
    end

    def allowed_update_attributes
      allowed_attributes
    end

    def permitted_params
      attrs = create_action? ?
        allowed_create_attributes :
        allowed_update_attributes
      return resource_params.permit(attrs) if attrs
      warn "#{model_class.to_s} is missing strong parameters!"
      params
    end

    def resource_params
      params.require(model_name)
    end

    # set params like user_id that a user is not permitted to supply but
    # is required in order to create or update a record in the default_params
    # hash
    def default_params
      @default_params ||= {}
    end

    def default_includes
      []
    end

    #########################################
    # HELPER METHODS
    #########################################
    def create_action?
      ['create'].include?(action_name)
    end

    def read_action?
      request.get?
    end

    def update_action?
      ['update'].include?(action_name) || request.put?
    end

    def destroy_action?
      ['destroy'].include?(action_name) || request.delete?
    end

    def collection_action?
      read_action? && !member_action?
    end

    def member_action?
      create_action? || params[:id].present?
    end

    def model_class
      @model_class ||= controller_name.classify.constantize
    end

    def model_name
      @model_name ||= controller_name.singularize
    end

    def current_user
      User.last
    end
  end
end
