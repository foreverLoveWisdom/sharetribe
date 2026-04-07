module FeatureTests
  module Section
    module AdminSidebar
      extend Capybara::DSL

      module_function

      def click_payments_link
        sidebar.find("a[aria-controls='paymentsystem'], a[aria-controls='paymentsystem-mobile'], a[href='#paymentsystem'], a[href='#paymentsystem-mobile']").click
      end

      def click_paypal_link
        sidebar.find("li#paypal a, li#paypal-mobile a").click
      end

      def click_stripe_link
        sidebar.find("li#stripe a, li#stripe-mobile a").click
      end

      def sidebar
        find("aside.sidenav-container .sidenav-links")
      end
    end
  end
end
