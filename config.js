/* ============================================================
   PHOTOSCAN — shared front-end config
   Both the storefront (/index.html) and the admin panel (/admin)
   read these two values. The anon / publishable key is SAFE to
   commit and expose in the browser — Row Level Security in the
   database is what actually protects your data.
   Never put the service_role / secret key here.
   ============================================================ */
window.PHOTOSCAN_CONFIG = {
     SUPABASE_URL: "https://lxkhltmnxhwdrndmkxnq.supabase.co",
     ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx4a2hsdG1ueGh3ZHJuZG1reG5xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUyMzE0ODIsImV4cCI6MjEwMDgwNzQ4Mn0.2Ks2qLY2dGc4F1PmQS_htlJfzB4eqVEYMF7uB6WC0aU"
   };