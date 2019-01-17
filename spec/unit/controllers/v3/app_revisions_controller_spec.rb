require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe AppRevisionsController, type: :controller do
  describe '#show' do
    let!(:droplet) { VCAP::CloudController::DropletModel.make }
    let!(:app_model) { VCAP::CloudController::AppModel.make(droplet: droplet) }
    let!(:space) { app_model.space }
    let(:user) { VCAP::CloudController::User.make }
    let(:revision) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 808, droplet_guid: droplet.guid) }

    before do
      set_current_user(user)
      allow_user_read_access_for(user, spaces: [space])
      allow_user_secret_access(user, space: space)
    end

    it 'returns 200 and shows the revision' do
      get :show, params: { guid: app_model.guid, revision_guid: revision.guid }

      expect(response.status).to eq(200)
      expect(parsed_body).to be_a_response_like(
        {
          'guid' => revision.guid,
          'version' => revision.version,
          'droplet' => {
            'guid' => droplet.guid
          },
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/#{revision.guid}"
            }
          },
          'metadata' => {
            'labels' => {},
            'annotations' => {}
          }
        }
      )
    end

    it 'still shows the revision droplet_guid even after the droplet is deleted' do
      droplet_guid = droplet.guid
      droplet.delete

      get :show, params: { guid: app_model.guid, revision_guid: revision.guid }

      expect(response.status).to eq(200)
      expect(parsed_body).to be_a_response_like(
        {
          'guid' => revision.guid,
          'version' => revision.version,
          'droplet' => {
            'guid' => droplet_guid
          },
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/#{revision.guid}"
            }
          },
          'metadata' => {
            'labels' => {},
            'annotations' => {}
          }
        }
      )
    end

    it 'raises an ApiError with a 404 code when the app does not exist' do
      get :show, params: { guid: 'hahaha', revision_guid: revision.guid }

      expect(response.status).to eq 404
      expect(response.body).to include 'ResourceNotFound'
    end

    it 'raises an ApiError with a 404 code when the revision does not exist' do
      get :show, params: { guid: app_model.guid, revision_guid: 'hahaha' }

      expect(response.status).to eq 404
      expect(response.body).to include 'ResourceNotFound'
    end

    it 'raises an ApiError with a 404 code when the revision belongs to a different app' do
      other_app = VCAP::CloudController::AppModel.make

      get :show, params: { guid: other_app.guid, revision_guid: revision.guid }

      expect(response.status).to eq 404
      expect(response.body).to include 'ResourceNotFound'
    end

    context 'permissions' do
      context 'when the user does not have cc read scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: [])
        end

        it 'raises an ApiError with a 403 code' do
          get :show, params: { guid: app_model.guid, revision_guid: revision.guid }

          expect(response.body).to include 'NotAuthorized'
          expect(response.status).to eq 403
        end
      end

      context 'when the user cannot read the app' do
        let(:space) { app_model.space }

        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          get :show, params: { guid: app_model.guid, revision_guid: revision.guid }

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end
    end
  end

  describe '#index' do
    let!(:app_model) { VCAP::CloudController::AppModel.make }
    let!(:app_without_revisions) { VCAP::CloudController::AppModel.make(space: space) }
    let!(:space) { app_model.space }
    let(:user) { VCAP::CloudController::User.make }
    let!(:revision1) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 808) }
    let!(:revision2) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 809) }
    let!(:revision_for_another_app) { VCAP::CloudController::RevisionModel.make }

    before do
      set_current_user(user)
      allow_user_read_access_for(user, spaces: [space])
      allow_user_secret_access(user, space: space)
    end

    it 'returns 200 and shows the revisions' do
      get :index, params: { guid: app_model.guid }

      expect(response.status).to eq(200)
      expect(parsed_body['resources'].map { |r| r['guid'] }).to contain_exactly(revision1.guid, revision2.guid)
    end

    context 'filters' do
      let!(:revision3) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 810) }

      it 'by version' do
        get :index, params: { guid: app_model.guid, versions: '808,810' }

        expect(response.status).to eq(200)
        expect(parsed_body['resources'].map { |r| r['guid'] }).to contain_exactly(revision1.guid, revision3.guid)
      end
    end

    it 'raises an ApiError with a 404 code when the app does not exist' do
      get :index, params: { guid: 'hahaha' }

      expect(response.status).to eq 404
      expect(response.body).to include 'ResourceNotFound'
    end

    it 'returns an empty array when the app has no revisions' do
      get :index, params: { guid: app_without_revisions.guid }

      expect(response.status).to eq 200
      expect(parsed_body['resources']).to be_empty
    end

    context 'permissions' do
      context 'when the user does not have cc read scope' do
        before do
          set_current_user(VCAP::CloudController::User.make, scopes: [])
        end

        it 'raises an ApiError with a 403 code' do
          get :index, params: { guid: app_model.guid }

          expect(response.body).to include 'NotAuthorized'
          expect(response.status).to eq 403
        end
      end

      context 'when the user cannot read the app' do
        let(:space) { app_model.space }

        before do
          disallow_user_read_access(user, space: space)
        end

        it 'returns a 404 ResourceNotFound error' do
          get :index, params: { guid: app_model.guid }

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end
    end
  end

  describe '#update' do
    let!(:droplet) { VCAP::CloudController::DropletModel.make }
    let!(:app_model) { VCAP::CloudController::AppModel.make(droplet: droplet) }
    let!(:space) { app_model.space }
    let(:user) { VCAP::CloudController::User.make }
    let(:labels) do
      {
        fruit: 'pears',
        truck: 'hino'
      }
    end
    let(:annotations) do
      {
        potato: 'celandine',
        beet: 'formanova',
      }
    end
    let(:revision) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 808, droplet_guid: droplet.guid) }
    let!(:update_message) do
      {
        metadata: {
          labels: {
            fruit: 'passionfruit'
          },
          annotations: {
            potato: 'adora'
          }
        }
      }
    end

    before do
      set_current_user(user)
      allow_user_read_access_for(user, spaces: [space])
      allow_user_write_access(user, space: space)

      VCAP::CloudController::LabelsUpdate.update(revision, labels, VCAP::CloudController::RevisionLabelModel)
      VCAP::CloudController::AnnotationsUpdate.update(revision, annotations, VCAP::CloudController::RevisionAnnotationModel)
    end

    context 'when the user can modify the app' do
      it 'returns a 200 and the updated revision' do
        patch :update, params: { guid: app_model.guid, revision_guid: revision.guid }.merge(update_message), as: :json

        expect(response.status).to eq(200)
        expect(parsed_body).to be_a_response_like(
          {
            'guid' => revision.guid,
            'version' => revision.version,
            'droplet' => {
              'guid' => droplet.guid
            },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/#{revision.guid}"
              }
            },
            'metadata' => {
              'labels' => { 'fruit' => 'passionfruit', 'truck' => 'hino' },
              'annotations' => { 'potato' => 'adora', 'beet' => 'formanova' }
            }
          }
        )
      end
    end

    context 'when the user sets metadata to null' do
      let!(:update_message) do
        {
          metadata: {
            labels: {
              fruit: nil
            },
            annotations: {
              potato: nil
            }
          }
        }
      end

      it 'is removed' do
        patch :update, params: { guid: app_model.guid, revision_guid: revision.guid }.merge(update_message), as: :json

        expect(response.status).to eq(200)
        expect(parsed_body).to be_a_response_like(
          {
            'guid' => revision.guid,
            'version' => revision.version,
            'droplet' => {
              'guid' => droplet.guid
            },
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/#{revision.guid}"
              }
            },
            'metadata' => {
              'labels' => { 'truck' => 'hino' },
              'annotations' => { 'beet' => 'formanova' }
            }
          }
        )
      end
    end

    context 'when the user cannot read from the space' do
      before do
        disallow_user_read_access(user, space: space)
      end

      it 'returns a 404' do
        patch :update, params: { guid: app_model.guid, revision_guid: revision.guid }.merge(update_message), as: :json

        expect(response.status).to eq(404)
      end
    end

    context 'when the user cannot modify the app' do
      before do
        disallow_user_write_access(user, space: space)
      end

      it 'returns a 403' do
        patch :update, params: { guid: app_model.guid, revision_guid: revision.guid }.merge(update_message), as: :json

        expect(response.status).to eq(403)
      end
    end

    context 'when the user gives bad metadata' do
      let(:update_message) do
        {
          metadata: {
            annotations: {
              "": 'mashed',
              "/potato": '.value.'
            }
          }
        }
      end

      it 'returns a 422' do
        patch :update, params: { guid: app_model.guid, revision_guid: revision.guid }.merge(update_message), as: :json

        expect(response.status).to eq(422)
      end
    end
  end
end