---
name: controllers
description: "Conventions des controllers HubEE : controller RESTful (actions standard, before_action, strong params, autorisation Pundit, réponses render/redirect avec statuts). À utiliser pour créer ou modifier un controller dans app/controllers/. Pour décider si une logique doit rester dans le controller ou basculer vers un pattern dédié, voir la skill choosing-a-pattern."
globs:
  - "app/controllers/**/*.rb"
---

# Controllers Skill

Conventions d'implémentation des controllers. Le controller n'accueille que le scaffold CRUD et l'orchestration HTTP ; le choix « cette logique reste-t-elle ici ou bascule-t-elle vers un pattern dédié » est tranché par `choosing-a-pattern` (§ « Choisir un pattern »).

## Controller RESTful

```ruby
class SubscriptionsController < ApplicationController
  before_action :set_subscription, only: %i[show edit update destroy]

  def index
    @subscriptions = policy_scope(Subscription)
      .includes(:organization, :process)
      .page(params[:page])
  end

  def show
    authorize @subscription
  end

  def new
    @subscription = Subscription.new
    authorize @subscription
  end

  def create
    @subscription = Subscription.new(subscription_params)
    authorize @subscription

    if @subscription.save
      redirect_to @subscription, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @subscription
  end

  def update
    authorize @subscription

    if @subscription.update(subscription_params)
      redirect_to @subscription, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @subscription
    @subscription.destroy
    redirect_to subscriptions_path, notice: t(".success")
  end

  private

  def set_subscription
    @subscription = Subscription.find(params[:id])
  end

  def subscription_params
    params.require(:subscription).permit(:organization_id, :process_id, :notes)
  end
end
```

Dès que la logique d'une action **dépasse le scaffold**, elle sort du controller : quel pattern l'accueille relève de `choosing-a-pattern` (§ « Choisir un pattern »).
