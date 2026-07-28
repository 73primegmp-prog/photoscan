-- ============================================================================
-- PHOTOSCAN · 0004 · SEED  (mirrors the storefront PRODUCTS / CATS exactly)
-- Safe to re-run: upserts on primary key.
-- ============================================================================

insert into categories (id, title, sort) values
  ('corporate', 'Corporate & Awards',       1),
  ('couples',   'Couples & Anniversaries',  2),
  ('birthday',  'Birthday & Occasions',     3),
  ('eco',       'Eco-Friendly Gifts',       4)
on conflict (id) do update set title = excluded.title, sort = excluded.sort;

insert into products
  (id, category_id, name, sku, price_inr, mrp_inr, material, fields, rating, reviews, badge, blurb) values
  ('aw-acr','corporate','Summit Acrylic Excellence Award','AW-ACR-11',1199,1499,'acrylic','{text}',4.9,412,'Bestseller','Beveled acrylic award, laser-engraved with name, title and achievement.'),
  ('aw-wd','corporate','Heritage Wooden Award Plaque','AW-WD-07',999,1299,'wood','{text,photo}',4.8,288,null,'Solid sheesham plaque with deep laser engraving and optional crest.'),
  ('pen-igi','corporate','IGI Laser-Marked Executive Pen','PEN-IGI-03',299,399,'metal','{text}',4.9,961,'Corporate favourite','Brushed-metal roller pen, precision laser-marked with name or logo.'),
  ('btl-sub','corporate','Meridian Sublimation Bottle','BTL-SUB-05',549,699,'metal','{photo,text}',4.7,337,null,'Insulated steel bottle, full-wrap sublimation print that never fades.'),
  ('np-exec','corporate','Executive Engraved Nameplate','NP-EXE-02',699,899,'wood','{text}',4.8,154,null,'Desk nameplate in wood + acrylic, engraved with name and designation.'),
  ('cp-inf','couples','Infinity Wooden Photo Frame','CP-WD-21',699,899,'wood','{photo,text}',4.9,523,'Bestseller','Infinity-cut wooden frame holding your photo with an engraved date.'),
  ('cp-led','couples','Aurora LED Acrylic Photo Stand','CP-LED-14',899,1199,'led','{photo,text}',4.9,678,'Glows','Edge-lit acrylic that makes your photo glow — 7 warm light modes.'),
  ('cp-clk','couples','Together Wooden Couple''s Clock','CP-CLK-09',849,1099,'wood','{photo,text}',4.8,241,null,'Silent-sweep wooden clock printed with your favourite portrait.'),
  ('cp-led2','couples','Radiance LED Acrylic Moment','LED-24',999,1299,'led','{photo,text}',4.9,389,null,'A cinematic glowing keepsake for anniversaries and proposals.'),
  ('bd-col','birthday','Memory Lane Wood Photo Collage','BD-WD-33',749,999,'wood','{photo}',4.8,466,'Bestseller','Sublimation wood panel collaging your best moments into one gift.'),
  ('bd-wlt','birthday','Personalised Leather-Grain Wallet','BD-WLT-18',599,799,'leather','{text}',4.7,302,null,'Slim wallet embossed with a name or short message.'),
  ('bd-mug','birthday','Classic Photo Mug','BD-MUG-02',279,349,'ceramic','{photo,text}',4.8,1204,'Trending','Ceramic mug printed with your photo and caption, dishwasher-safe.'),
  ('bd-mug2','birthday','Magic Reveal Photo Mug','BD-MUG-07',329,449,'ceramic','{photo,text}',4.7,288,null,'Heat-reactive mug — the photo appears when hot coffee is poured.'),
  ('w51','eco','Living Oak Plant Plaque','W51',499,649,'plant','{text}',4.9,198,'Eco','Engraved wooden plaque cradling a real live desk plant. Grows with them.'),
  ('w54','eco','Fern & Grain Desk Plant','W54',549,699,'plant','{text}',4.8,141,null,'Hand-finished plaque + living fern, engraved with a name or note.'),
  ('w58','eco','Bamboo Wishes Plant Plaque','W58',599,749,'plant','{text}',4.9,167,'Eco','Lucky bamboo on an engraved plaque — a growing corporate gift.')
on conflict (id) do update set
  category_id=excluded.category_id, name=excluded.name, sku=excluded.sku,
  price_inr=excluded.price_inr, mrp_inr=excluded.mrp_inr, material=excluded.material,
  fields=excluded.fields, rating=excluded.rating, reviews=excluded.reviews,
  badge=excluded.badge, blurb=excluded.blurb, active=true;
