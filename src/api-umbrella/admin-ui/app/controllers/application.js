import Ember from 'ember';

export default Ember.Controller.extend({
  session: Ember.inject.service('session'),

  isLoading: null,

  actions: {
    logout() {
      this.get('session').invalidate();
    },
  },
});
