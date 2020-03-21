require 'rails_helper'

RSpec.describe Api::V1::Orders::BaseIndexPresenter do
  before do
    ActionController::Parameters.permit_all_parameters = true
  end
  include_examples 'authorize user', 'admin'

  describe 'with blank params' do
    let!(:orders) { create_list(:order, 5) }
    let!(:archive_orders) { create_list(:order, 2, archive: true) }

    it 'return all orders' do
      expect(described_class.new({}).orders.ids.uniq)
        .to match_array(orders.map(&:id) | archive_orders.map(&:id))
    end

    it 'return sorted orders' do
      last_date = (Time.current - 1.day)
      first_date = (Time.current + 1.day)

      create(:order, created_at: last_date)
      create(:order, created_at: first_date)

      orders = described_class.new({}).orders

      expect(orders.first.created_at).to match_date_time(first_date)
      expect(orders.last.created_at).to match_date_time(last_date)
    end
  end

  describe 'when set `my_partners`' do
    let(:my_partner) { create(:partner, manager: user) }
    let!(:orders) { create_list(:order, 5) }
    let!(:my_orders) { create_list(:order, 5, partner: my_partner) }

    context 'when `my_partners` is true' do
      let(:params) { { my_partners: 'true' } }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq).to match_array(my_orders.map(&:id))
      end
    end

    context 'when `my_partners` is 1' do
      let(:params) { { my_partners: '1' } }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq).to match_array(my_orders.map(&:id))
      end
    end

    context 'when `my_partners` is 0' do
      let(:params) { { my_partners: '0' } }

      it 'should return not filtered collection' do
        expect(described_class.new(params).orders.ids.uniq)
          .to match_array((orders | my_orders).map(&:id))
      end
    end

    context 'when `my_partners` is false' do
      let(:params) { { my_partners: 'false' } }

      it 'should return not filtered collection' do
        expect(described_class.new(params).orders.ids.uniq)
          .to match_array((orders | my_orders).map(&:id))
      end
    end
  end

  describe 'when set `territorial_bank_id`' do
    before do
      user.territorial_bank = territorial_bank
      user.save(validate: false)
    end

    let(:my_partner) { create(:partner, manager: user) }
    let!(:orders) { create_list(:order, 5) }
    let!(:my_orders) { create_list(:order, 5, partner: my_partner) }
    let(:territorial_bank) { create(:territorial_bank) }
    let(:params) { { territorial_bank_id: territorial_bank.id } }

    it 'should return filtered collection' do
      expect(described_class.new(params).orders.ids.uniq).to match_array(my_orders.map(&:id))
    end
  end

  describe 'when set `id`' do
    let!(:orders) { create_list(:order, 5) }
    let(:params) { ActionController::Parameters.new(id: orders.sample.id) }

    it 'should return filtered collection' do
      expect(described_class.new(params).orders.ids.uniq).to match_array([params[:id]])
    end
  end

  describe 'when set `merchant_id`' do
    let(:orders) { create_list(:order, 5) }
    let(:merchant_id) { orders.sample.merchant_id }
    let(:params) { ActionController::Parameters.new(merchant_id: merchant_id) }

    it 'should return filtered collection' do
      expect(described_class.new(params).orders.map(&:merchant_id).uniq)
        .to match_array([merchant_id])
    end
  end

  describe 'when set `product_id`' do
    let(:orders) { create_list(:order, 5) }
    let(:product_id) { orders.sample.product_profile.product_id }
    let(:params) { ActionController::Parameters.new(product_id: product_id) }

    it 'should return filtered collection' do
      expect(
        described_class.new(params).orders.map { |order| order.product_profile.product_id }.uniq
      ).to match_array([product_id])
    end
  end

  describe 'when set `channel_id`' do
    let!(:other_user_orders) do
      orders = create_list(:order, 5)
      orders.map { |order| order.update!(created_by_user: create(:user)) }
      orders
    end
    let(:orders) { create_list(:order, 5) }
    let(:channel_id) { orders.sample.created_by_user.channel_id }
    let(:params) { ActionController::Parameters.new(channel_id: channel_id) }

    it 'should return filtered collection' do
      expect(
        described_class.new(params).orders.map { |order| order.created_by_user.channel_id }.uniq
      ).to match_array([channel_id])
    end
  end

  describe 'when set `partner_id`' do
    let(:orders) { create_list(:order, 5, :with_partner) }
    let(:partner_id) { orders.sample.partner_id }
    let(:params) { ActionController::Parameters.new(partner_id: partner_id) }

    it 'should return filtered collection' do
      expect(described_class.new(params).orders.map(&:partner_id).uniq).to match_array([partner_id])
    end
  end

  describe 'when set `user_id`' do
    let(:orders) { create_list(:order, 5) }
    let(:user_id) { orders.sample.created_by_user_id }
    let(:params) { ActionController::Parameters.new(user_id: user_id) }

    it 'should return filtered collection' do
      expect(described_class.new(params).orders.map(&:created_by_user_id).uniq)
        .to match_array([user_id])
    end
  end

  describe 'when set `assigned_to_user_id`' do
    let(:orders) { create_list(:order, 5) }
    let(:assigned_to_user_id) { orders.sample.assigned_to_user_id }
    let(:params) { ActionController::Parameters.new(assigned_to_user_id: assigned_to_user_id) }

    it 'should return filtered collection' do
      expect(described_class.new(params).orders.map(&:assigned_to_user_id).uniq)
        .to match_array([assigned_to_user_id])
    end
  end

  describe 'when set `status_id`' do
    let(:orders) { create_list(:order, 5) }
    let(:status_id) { orders.sample.order_status_id }
    let(:params) { ActionController::Parameters.new(status_id: status_id) }

    it 'should return filtered collection' do
      expect(described_class.new(params).orders.map(&:order_status_id).uniq)
        .to match_array([status_id])
    end
  end

  describe 'when set `from`' do
    let!(:orders) { create_list(:order, 5) }
    let!(:old_order) { create :order, created_at: 5.days.ago }
    let(:params) do
      ActionController::Parameters.new(from: I18n.l(3.days.ago, format: :inverse_short))
    end

    it 'should return filtered collection' do
      expect(described_class.new(params).orders.ids.uniq).to match_array(orders.map(&:id))
    end
  end

  describe 'when set `to`' do
    let!(:orders) { create_list(:order, 5, created_at: 5.days.ago) }
    let!(:new_order) { create :order }
    let(:params) do
      ActionController::Parameters.new(to: I18n.l(3.days.ago, format: :inverse_short))
    end

    it 'should return filtered collection' do
      expect(described_class.new(params).orders.ids.uniq).to match_array(orders.map(&:id))
    end
  end

  context 'when set `assignment_type`' do
    describe 'when assignment_type is `assigned_to_any_user`' do
      let!(:orders) { create_list(:order, 5, assigned_to_user: user) }
      let!(:not_assigned_orders) { create_list(:order, 5) }
      let(:params) { ActionController::Parameters.new(assignment_type: 'assigned_to_any_user') }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq).to match_array(orders.map(&:id))
      end
    end

    describe 'when assignment_type is `unassigned`' do
      let!(:orders) { create_list(:order, 5, assigned_to_user: user) }
      let!(:not_assigned_orders) { create_list(:order, 5) }
      let(:params) { ActionController::Parameters.new(assignment_type: 'unassigned') }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq)
          .to match_array(not_assigned_orders.map(&:id))
      end
    end

    describe 'when assignment_type is `assigned_to_current_user`' do
      let!(:orders_assigned_on_me) { create_list(:order, 5, assigned_to_user: user) }
      let!(:orders_assigned_on_other) { create_list(:order, 5, assigned_to_user: create(:user)) }
      let(:params) { ActionController::Parameters.new(assignment_type: 'assigned_to_current_user') }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq)
          .to match_array(orders_assigned_on_me.map(&:id))
      end
    end
  end

  describe 'when set `city_id`' do
    let!(:orders) { create_list(:order, 5) }
    let(:city) { create(:city) }
    let(:field) do
      Field.create!(name: 'merchant_branch_city_id', field_type: 'combobox', data_type: 'list')
    end
    let!(:orders_with_city) do
      collection = create_list(:order, 5)
      collection.map do |order|
        order.order_details << OrderDetail.create!(field: field, value: city.id)
      end
      collection
    end
    let(:params) { ActionController::Parameters.new(city_id: city.id) }

    it 'should return filtered collection' do
      expect(described_class.new(params).orders.ids.uniq)
        .to match_array(orders_with_city.map(&:id))
    end
  end

  describe 'when set `region_id`' do
    let!(:orders) { create_list(:order, 5) }
    let(:region) { create(:region) }
    let(:field) do
      Field.create!(name: 'merchant_branch_region_id', field_type: 'combobox', data_type: 'list')
    end
    let!(:orders_with_region) do
      collection = create_list(:order, 5)
      collection.map do |order|
        order.order_details << OrderDetail.create!(field: field, value: region.id)
      end
      collection
    end
    let(:params) { ActionController::Parameters.new(region_id: region.id) }

    it 'should return filtered collection' do
      expect(described_class.new(params).orders.ids.uniq)
        .to match_array(orders_with_region.map(&:id))
    end
  end

  describe 'when set `branch_id`' do
    let!(:orders) { create_list(:order, 5) }
    let(:merchant_branch) { create(:merchant_branch) }
    let(:field) do
      Field.create!(name: 'merchant_branch_id', field_type: 'combobox', data_type: 'list')
    end
    let!(:orders_with_branch) do
      collection = create_list(:order, 5)
      collection.map do |order|
        order.order_details << OrderDetail.create!(field: field, value: merchant_branch.id)
      end
      collection
    end
    let(:params) { ActionController::Parameters.new(branch_id: merchant_branch.id) }

    it 'should return filtered collection' do
      expect(described_class.new(params).orders.ids.uniq)
        .to match_array(orders_with_branch.map(&:id))
    end
  end

  describe 'when set `new`' do
    let!(:orders) { create_list(:order, 5) }
    let!(:unread_orders) do
      orders = create_list(:order, 5)
      orders.map { |order| order.readers.destroy_all }
      orders
    end
    let(:params) { ActionController::Parameters.new(new: '1') }

    it 'should return only unreaded collection' do
      expect(described_class.new(params).orders.ids.uniq).to match_array(unread_orders.map(&:id))
    end
  end

  describe 'when set `new_comments`' do
    let(:orders) do
      orders = create_list(:order, 5, :with_unread_comments)
      orders.map(&:mark_comments_as_read)
      orders
    end
    let!(:unread_orders) { create_list(:order, 5, :with_unread_comments) }
    let(:params) { ActionController::Parameters.new(new_comments: '1') }

    it 'should return only unreaded collection' do
      expect(described_class.new(params).orders.ids.uniq).to match_array(unread_orders.map(&:id))
    end
  end

  describe 'when set `is_deleted`' do
    let!(:orders) { create_list(:order, 5) }
    let!(:deleted_orders) { create_list(:order, 5, is_deleted: true) }
    let(:params) { ActionController::Parameters.new(is_deleted: '1') }

    it 'should return only deleted collection' do
      expect(described_class.new(params).orders.ids.uniq).to match_array(deleted_orders.map(&:id))
    end
  end

  describe 'when set `assigned_to_user_id`' do
    let(:some_user) { create(:user) }
    let!(:orders) { create_list(:order, 5) }
    let!(:assigned_orders) { create_list(:order, 5, assigned_to_user_id: some_user.id) }
    let(:params) { ActionController::Parameters.new(assigned_to_user_id: some_user.id) }

    it 'should return filtered collection' do
      expect(described_class.new(params).orders.ids.uniq).to match_array(assigned_orders.map(&:id))
    end
  end

  context 'when set `query`' do
    describe 'when search string from number' do
      let!(:orders) { create_list(:order, 5) }
      let!(:order) { create(:order, number: 'SEARCH-0001') }
      let(:params) { ActionController::Parameters.new(query: 'search') }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq).to match_array([order.id])
      end
    end

    describe 'when search string from product_profile name' do
      let!(:orders) { create_list(:order, 5) }
      let!(:order) do
        product = create(:product, name: 'SEARCh')
        product_profile = create(:product_profile, product: product)
        create(:order, product_profile: product_profile)
      end
      let(:params) { ActionController::Parameters.new(query: 'search') }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq).to match_array([order.id])
      end
    end

    describe 'when search string from created_by_user last_name' do
      let!(:orders) { create_list(:order, 5) }
      let!(:order) do
        order = create(:order)
        order.created_by_user = create(:user, last_name: 'SEARCh')
        order.save!
        order
      end
      let(:params) { ActionController::Parameters.new(query: 'search') }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq).to match_array([order.id])
      end
    end

    describe 'when search string from created_by_user username' do
      let!(:orders) { create_list(:order, 5) }
      let!(:order) do
        order = create(:order)
        order.created_by_user = create(:user, username: 'SEARCh')
        order.save!
        order
      end
      let(:params) { ActionController::Parameters.new(query: 'search') }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq).to match_array([order.id])
      end
    end

    describe 'when search string from created_by_user partners name' do
      let!(:orders) { create_list(:order, 5) }
      let!(:order) do
        order = create(:order)
        partner = create(:partner, name: 'SEARCh')
        order.created_by_user = create(:user, partner: partner)
        order.save!
        order
      end
      let(:params) { ActionController::Parameters.new(query: 'search') }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq).to match_array([order.id])
      end
    end

    describe 'when search string from orders_details value if orders_detail is vat_number' do
      let!(:orders) { create_list(:order, 5) }
      let(:field) do
        Field.create!(name: 'vat_number', field_type: 'combobox', data_type: 'list')
      end
      let!(:order) do
        order = create(:order)
        order_detail = OrderDetail.create!(field: field, value: 'search')
        order.order_details << order_detail
        order
      end
      let(:params) { ActionController::Parameters.new(query: 'search') }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq).to match_array([order.id])
      end
    end

    describe 'when search string from orders_details value if orders_detail is last_name' do
      let!(:orders) { create_list(:order, 5) }
      let(:field) do
        Field.create!(name: 'last_name', field_type: 'combobox', data_type: 'list')
      end
      let!(:order) do
        order = create(:order)
        order_detail = OrderDetail.create!(field: field, value: 'search')
        order.order_details << order_detail
        order
      end
      let(:params) { ActionController::Parameters.new(query: 'search') }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq).to match_array([order.id])
      end
    end

    describe 'when search string from orders_details value if orders_detail is mobile_phone' do
      let!(:orders) { create_list(:order, 5) }
      let(:field) do
        Field.create!(name: 'mobile_phone', field_type: 'combobox', data_type: 'list')
      end
      let!(:order) do
        order = create(:order)
        order_detail = OrderDetail.create!(field: field, value: 'search')
        order.order_details << order_detail
        order
      end
      let(:params) { ActionController::Parameters.new(query: 'search') }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq).to match_array([order.id])
      end
    end

    describe 'when search string from orders_details value if orders_detail is company_name' do
      let!(:orders) { create_list(:order, 5) }
      let(:field) do
        Field.create!(name: 'company_name', field_type: 'combobox', data_type: 'list')
      end
      let!(:order) do
        order = create(:order)
        order_detail = OrderDetail.create!(field: field, value: 'search')
        order.order_details << order_detail
        order
      end
      let(:params) { ActionController::Parameters.new(query: 'search') }

      it 'should return filtered collection' do
        expect(described_class.new(params).orders.ids.uniq).to match_array([order.id])
      end
    end
  end
end
