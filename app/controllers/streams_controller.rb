#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require File.join(Rails.root, "lib", "stream", "aspect")
require File.join(Rails.root, "lib", "stream", "multi")
require File.join(Rails.root, "lib", "stream", "comments")
require File.join(Rails.root, "lib", "stream", "likes")
require File.join(Rails.root, "lib", "stream", "mention")
require File.join(Rails.root, "lib", "stream", "followed_tag")
require File.join(Rails.root, "lib", "stream", "activity")


class StreamsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :save_selected_aspects, :only => :aspects
  before_filter :redirect_unless_admin, :only => :public

  respond_to :html,
             :mobile,
             :json

  def aspects
    aspect_ids = (session[:a_ids] ? session[:a_ids] : [])
    @stream = Stream::Aspect.new(current_user, aspect_ids,
                                 :max_time => max_time)
    stream_responder
  end

  def public
    stream_responder(Stream::Public)
  end

  def activity
    stream_responder(Stream::Activity)
  end

  def multi
    @stream = Stream::Public.new(current_user, :max_time => max_time)
    stream_json = PostPresenter.collection_json(@stream.stream_posts, current_user)
    respond_to do |format|
      format.html do
        gon.stream = stream_json
        render :nothing => true, :layout => "post"
      end
      format.mobile { render 'layouts/main_stream' }
      format.json { render :json => stream_json }
    end
  end

  def popular
    posts = Post.order("(exp(posts.likes_count) + posts.comments_count *2 - (exp(extract(day from age(created_at)) + 1))) DESC").limit(30).all

    stream_json = PostPresenter.collection_json(posts, current_user)
    respond_to do |format|
      format.html do
        gon.stream = stream_json
        render :nothing => true, :layout => "post"
      end
      format.mobile { render 'layouts/main_stream' }
      format.json { render :json => stream_json }
    end
  end

  def commented
    stream_responder(Stream::Comments)
  end

  def liked
    stream_responder(Stream::Likes)
  end

  def mentioned
    stream_responder(Stream::Mention)
  end

  def followed_tags
    stream_responder(Stream::FollowedTag)
  end

  private

  def stream_responder(stream_klass=nil)
    if stream_klass.present?
      @stream ||= stream_klass.new(current_user, :max_time => max_time)
    end

    respond_with do |format|
      format.html { render 'layouts/main_stream' }
      format.mobile { render 'layouts/main_stream' }
      format.json do 
        render :json => @stream.stream_posts.map {|p| LastThreeCommentsDecorator.new(PostPresenter.new(p, current_user)) }
      end
    end
  end

  def save_selected_aspects
    if params[:a_ids].present?
      session[:a_ids] = params[:a_ids]
    end
  end
end
