  #   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require Rails.root.join("app", "presenters", "post_presenter")

class PostsController < ApplicationController
  include PostsHelper
  
  before_filter :authenticate_user!, :except => [:show, :frame, :iframe, :screenshot, :oembed, :interactions, :next, :previous]
  before_filter :set_format_if_malformed_from_status_net, :only => :show
  before_filter :find_post, :only => [:show, :screenshot, :frame, :next, :previous, :interactions, :toggle_featured, :toggle_staff_picked]

  layout 'post'
  
  rescue_from ActiveRecord::RecordNotFound do
    render :file => "#{Rails.root}/public/404", :formats => [:html], :layout => false, :status => 404
  end

  respond_to :html,
             :mobile,
             :json,
             :xml

  def new
    render :text => "", :layout => true
  end

  def show
    mark_corresponding_notification_read if user_signed_in?

    respond_to do |format|
      format.html{ gon.post = PostPresenter.new(@post, current_user).as_json(lite?: true); render 'posts/show' }
      format.xml{ render :xml => @post.to_diaspora_xml }
      format.mobile{render 'posts/show', :layout => "application"}
      format.json{ render :json => PostPresenter.new(@post, current_user).as_json(lite?: true) }
    end
  end

  def iframe
    render :text => post_iframe_url(params[:id]), :layout => false
  end

  def frame
    gon.post = PostPresenter.new(@post, current_user); 
    render :text => "", :layout => true
  end

  def screenshot
    @post.re_screenshot_async
    redirect_to post_path @post
  end

  def oembed
    post_id = OEmbedPresenter.id_from_url(params.delete(:url))
    post = Post.find_by_guid_or_id_with_user(post_id, current_user)
    if post.present?
      oembed = OEmbedPresenter.new(post, params.slice(:format, :maxheight, :minheight))
      render :json => oembed
    else
      render :nothing => true, :status => 404
    end
  end

  def next
    next_post = Post.visible_from_author(@post.author, current_user).newer(@post)

    respond_to do |format|
      format.html{ redirect_to post_path(next_post) }
      format.json{ render :json => PostPresenter.new(next_post, current_user)}
    end
  end

  def previous
    previous_post = Post.visible_from_author(@post.author, current_user).older(@post)

    respond_to do |format|
      format.html{ redirect_to post_path(previous_post) }
      format.json{ render :json => PostPresenter.new(previous_post, current_user)}
    end
  end

  def interactions
    render :json => PostInteractionPresenter.new(@post, current_user).as_json
  end

  def destroy
    find_current_user_post(params[:id])
    current_user.retract(@post)

    respond_to do |format|
      format.js { render 'destroy',:layout => false,  :format => :js }
      format.json { render :nothing => true, :status => 204 }
      format.any { redirect_to latest_path}
    end
  end

  def toggle_favorite
    find_current_user_post(params[:id])
    @post.favorite = !@post.favorite
    @post.save!
    render :nothing => true, :status => 202
  end

  def toggle_featured
    raise("you can't do that") unless Role.is_admin?(current_user.person)
    @post.toggle_featured!
    render :nothing => true, :status => 202
  end

  def toggle_staff_picked
    raise("you can't do that") unless Role.is_admin?(current_user.person)
    @post.toggle_staff_picked!
    render :nothing => true, :status => 202
  end

  protected

  def find_post #checks whether current user can see it
    @post = Post.find_by_guid_or_id_with_user(params[:id], current_user)
  end

  def find_current_user_post(id) #makes sure current_user can modify
    @post = current_user.posts.find(id)
  end

  def set_format_if_malformed_from_status_net
   request.format = :html if request.format == 'application/html+xml'
  end

  def mark_corresponding_notification_read
    if notification = Notification.where(:recipient_id => current_user.id, :target_id => @post.id).first
      notification.unread = false
      notification.save
    end
  end
end
