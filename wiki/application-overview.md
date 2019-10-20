# Application Overview

This document is intended for general reference, but primarily meant for facilitating onboarding of developers that are new to DiaperBase. Please feel free to contribute to this document, but bear in mind:

* The purpose of this document is to provide a preliminary understanding of how this app functions.
* The audience is "Rails developers", so it's ok to use Rails jargon, but concepts related to diaperbanking may need to be explained.
* Aim for a level of specificity that is functional. It should explain how data flows through the app, but avoid being overly technical about implementation, unless it's particularly noteworthy or a potential danger area.

## Background

Diaper banks are similar to food banks, if you've heard of those before. They are small repositories of sanitary materials primarily used by infants and children, and the typical recipients are underprivileged or lower-income families. According to the National Diaper Bank Network (NDBN), there are ~120 registered diaper banks, and likely many others that are not registered with the NDBN. Diaper banks also occasionally provide other sanitary materials such as menstrual supplies, car seats, and other items that can be dispensed to defray the costs of child-rearing.

One of the biggest problems consistently faced by diaper banks is the means to track their inventory, which sometimes sprawls across multiple storage locations. Most of them typically come up with some spreadsheet-based solution (Excel, Google Sheets, etc.), though some have used free or low-cost inventory software applications. Both solutions present challenges, either lack of data integrity and high labor cost in maintenance (the former) or lack of extensibility for adapting to new features (the latter).

## Purpose

This application is a solution that is custom-tailored around the specific needs of [**diaper banks**](#organization). We initially worked directly with several diaper banks to ascertain exactly how we could best meet their needs with software, and we offer it to them for free, since many diaperbanks are volunteer-driven and/or grant-funded, and any money they would spend on an application is money diverted from swaddling children.

The scope of this application (DiaperBase) is:

* Tracking incoming, outgoing, and retained inventory in a robust manner
* Providing reports and status of the inventory to the diaperbanks
* Facilitating their reporting needs (to both the NDBN as well as any grantors and community partners)
* Providing fulfillment for incoming requests from community partners (via PartnerBase, see [Appendix](#PartnerBase))

Things that are out of scope include:

* Directly tracking data of families, children, and recipients of sanitary supplies
* Directly working with community partners (see [Appendix](#Appendix))
* Any eCommerce functions (including the purchasing or vending of inventory)
* Performing Human Resource functions

## Introduction

Before we delve into the inner-workings of how this application functions, we'll begin with a 10,000 foot view of how inventory moves through the application. This will include some key terms in **bold**, those terms will be further defined in the [Appendix](#Appendix).

### The Flow of Data

![diaperbase-diagram](https://user-images.githubusercontent.com/502363/51081485-5eb49100-16be-11e9-9d10-c8bfa6572968.jpg)

#### Intake

A diaper bank will acquire inventory primarily through one of two methods: a [**Donation**](#donation) or a [**Purchase**](#purchase). Purchases are straightforward; the diaper bank spends its own money to Purchase inventory. Donations can be received through a few different means.

[**Diaper drives**](#diaper-drive) are like food drives &mdash; a campaign, typically with advertisement to the community, for the general public to provide needed Items to the diaper bank. Sometimes people will also donate inventory at a local Donation Site, outside of a Diaper Drive. Other than those two primary methods, there is a miscellaneous classification for diapers that are received (but not purchased) through other means.

Donations can also dropped off at [**Donation sites**](#donation-site). These are locations that have been designated as places where people can drop off donations.

Donations that don't fit into either of those types are classified as "Miscellaneous Donations."

Both Donation sites and diaper drives have to be created beforehand, but can be used repeatedly after that.

#### Retention

All inventory is physically stored at [**storage locations**](#storage-location). This is one area where the application is particularly useful, as some storage locations accrue large quantities of inventory over time. Each Storage Location can contain any number of [**Items**](#item) or types of Items, and if a diaper bank has multiple storage locations, it is possible for the same Item type to exist at multiple locations.

Sometimes, the diaper banks will need to make a correction, though this application calls them [**adjustments**](#adjustment).

When a diaper bank wants to move inventory from one Storage Location to another, they do so with a [**Transfer**](#transfer).

#### Output

When inventory leaves a diaper bank, it does so via a [**Distribution**](#distribution). These are either created implicitly from inbound PartnerBase [**requests**](#request), or created explicitly via the menu interface. When they are created explicitly, they pull from a single designated Storage Location, and are built in a similar fashion to donations, adjustments, transfers, etc. &mdash; Items are added and quantities are specified.

Distributions can be exported as PDFs, which diaper banks can use as printable manifests for the packages sent to the Community Partner.

[Community partners](#partner) then dispense the Items they receive to the clients/families.

## Application Architecture

This section is a more detailed, and more technical, explanation of how the application works internally.

### Multi-Tenancy

This application is multi-tenant. That means each diaper bank (this term is used interchangeably with [**Organization**](#organization)) has its own templated "section" of the application, and may act in that section without concern that its changes will affect other organizations (and vice versa).

When a user is signed in, they are automatically "jailed" to their organizational space, as indicated by the URL (which features a shortcode of their Organization in it).

#### Users

Every Organization has a user who is the "Organization admin" (typically the first user to sign up for that Organization). This user can perform administrative privileges on the Organization, such as changing the descriptive details, inviting other users, etc. Additional users are able to use most of the functions of their organizational space.

### Items

These are an important, but perhaps not immediately intuitive, aspect of the application. Items are, for example, "3T Diapers", "Baby Wipes", or "Boys Batman 4T Diapers" &mdash; they can be as generic or as specific as necessary, and organizations have full control over what Items they use in their instance of DiaperBase.

Every Item is also connected with a [**Canonical Item**](#canonical-item), which might also be called a "Base Item" (this might be a permanent name change in the near future). The Canonical Items are all very generic and refer to a functional commonality &mdash; "3T Diapers", "Huggies 3T Diapers", and "Boys Batman 3T Diapers" would all have "3T Diapers" as their Canonical Item base.

For a much more detailed and technical description of how these work, see the Wiki article on [Canonical Items](/rubyforgood/diaper/wiki/Canonical-Items).

Canonical Items are only really noticeable in two places: When creating a new Item, and when communicating between PartnerBase and DiaperBase. Aside from those, they're more of a concern of the `SiteAdmin` role. For the remainder of this document, when it refers to "Item", it is referring to `Item`, unless otherwise specified.

#### Item "Boxes" (LineItems & InventoryItems)

Because Items are only defining *types* of physical inventory, we need a vehicle to track *quantities*. This application does this by piggybacking on the association. We currently use two different kinds of associations: [**Line Items**](#line-item) and [**Inventory Items**](#inventory-item). The main practical difference between the two is that the quantities of "Line Items" are non-zero integers and the quantities of "Inventory Items" are natural numbers.

##### Line Items

These are the most common, and are used polymorphically for numerous models. The name "Line Item" was chosen because a "Line Item" is a single line on a list of Items, perhaps found on a manifest or roster. In this application, Line Items are like a plain box, labeled with an item type, that some number of Items are put into. That labeled box can only hold that kind of item, it can also hold negative quantities of that Item.

Line Items are used in Donations, Distributions, Adjustments, Transfers, Purchases, and generally any place where inventory is being moved somehow.

The behaviors of Line Items are consistent enough that the logic has been captured largely in the [Itemizable](/rubyforgood/diaper/blob/master/app/models/concerns/itemizable.rb) model concern.

##### Inventory Items

Inventory Items are similar to Line Items in their function, except it might be better to abstractly think of them as "shelves." They are only found in Storage Locations and are the resting place for inventory while it's retained by the Organization. Like Line Items, each Inventory Item can only track a single item type, but instead of associating with a polymorphic type, they only associate with Storage Locations (which hold physical inventory). They also differ in that they cannot be negative (you can't have -5 Baby Wipes, right?)

### Barcoding

One of the reasons that DiaperBase was built was specifically to offer the ability to expedite inventory tracking with barcodes. If you aren't familiar with the physical concept of how barcodes function, read up on [Code 39](https://en.wikipedia.org/wiki/Code_39) specifically &mdash; this allows us to encode letters and/or numbers into machine readable barcodes.

The TL;DR is that the barcode stripes correspond with actual letters and numbers, and when the barcode reader reads it, it just converts it into the alphanumeric version and appends a carriage return.

Our barcode UI controls specifically look for "an alphanumeric string followed by a carriage return (CHR 13)," and will use that to issue a lookup via Ajax.

#### Organization Barcodes

Organizations are encouraged to create their own barcodes. So long as the barcode value has not already been used by that Organization, they are free to use whatever Code39 barcode value they like.

Suggested uses include:

* Using the actual UPC on the packaging
* Creating barcodes that meaningfully track the Item name and quantity in the value (ie. 100X3TDIAPERS)
* Creating barcodes that track custom bundles the diaper bank frequently dispenses

Organization barcodes always take precedence when they do a lookup.

#### Global Barcodes

These are barcodes that act as "fall-throughs" and will generally be used to track product UPCs and map them to the appropriate Canonical Item type. (For example: pointing the UPC for 40 Huggies 3T, 48 Pampers 3T, and 24 Luvs 3T diaper packs all to the "3T Diapers" Canonical Item type). These are only entered by Site Administrators and must always point to a Canonical Item type.

#### Barcode Retrieval

Barcode records are either connected to an Organization and an `Item`, or they are labeled "global" and connected to a `CanonicalItem`. When a lookup is requested, it will look up the barcode (by its value) with the following order of priority (this was established in [#593](/rubyforgood/diaper/issues/593)):

1. Does the Organization have its own barcode defined with this value? (yields an `Item`)
2. Is there a global barcode defined for this value? (yields a `CanonicalItem`)
3. Prompt the user to create a new barcode record using this value

For the second Item, after the `CanonicalItem` is retrieved, it consults back to the Organization and finds the oldest `Item` (for that Organization) that uses the retrieved `CanonicalItem`.

## Appendix

### Glossary

The following is a list of terms found throughout this application along with their definitions. Some of these terms may vary depending on use case. For example, a **Partner** in the DiaperBase app is called a "Community Partner" by an end user at a diaper bank. We have explicitly coded all terms in the following manner:

* NDBN designates terms that are commonly used as diaper bank jargon
* DBA designates terms that apply to the DiaperBase app
  * Their corresponding models will follow the term, displayed in code format

If the term's plural form is irregular, it will also be included.

<a name="adjustment">DBA: **Adjustment**; model: `Adjustment`<br>
  When a diaper bank has to make a change to its on hand inventory totals, it creates an Adjustment. A single Adjustment can record the change of quantities for multiple different kinds of Items. These adjustments create a record internally for each transaction and are the only interface for an Organization to make direct changes to their inventories.

<a name="canonical-item">DBA: **Canonical Item**<br>
  This is the abstract base type for an `Item` object, and is used as the source of replication when a new Organization is created. Every `Item` must inherit from a Canonical Item. Canonical items create an implicit common language that can be used across both DiaperBase and PartnerBase.

<a name="diaper-drive">DBA: **Diaper Drive**; model: `DiaperDriveParticipant`<br>
NDBN: **diaper drive**<br>
  This is similar to a fundraiser or food drive. It is an often advertised campaign to the community with a declared intention to encourage donations from community members. Sometimes the Diaper Drive is held by individuals or organizations that are not the diaper bank themselves. Diaper banks like to track data on how successful their diaperdrives are, so we provide a means to track it.

<a name="distribution">DBA: **Distribution**<br>
  These are how diaper banks issue inventory to community partners. A Distribution can sometimes be connected with a Request from PartnerBase, but this isn't strictly required. The Distribution builds a manifest of items and quantities and ultimately handles the removal of inventory in a transaction. It's the primary interface for reducing inventory.

<a name="donation">DBA: **Donation**; model: `Donation`<br>
  This is one of the two ways that inventory is added to a diaper bank. Donations are inventory that is provided at no cost to the diaper bank. Internally, they are represented by the `Donation` model. These models are the primary interface for adding inventory to a diaper bank. When a Donation completes, it creates a transaction to add the inventory.

<a name="donation-site">DBA: **Donation Site**; model: `DonationSite`<br>
  These are physical locations where the general public can bring needed inventory to be donated to the diaper bank. They have a geographical address and are generally named.

<a name="inventory-item">DBA: **Inventory Item**; model: `InventoryItem`<br>
  This is an abstract "box" that records an item type with a quantity, and is generally held by a Storage Location. (See also: [Line Item](#line-item))

<a name="items">DBA: **Item**; model: `Item`<br>
  The data abstraction of a real-world object. An instance of `Item` is owned by an Organization. An Item does not have a quantity itself; the quantity is tracked in an associative record (such as [`Line Item`](#line-item) or [`Inventory Item`](#inventory-item)).

<a name="line-item">DBA: **Line Item**; model: `LineItem`<br>
  This is an abstract "box" that records an item type with a quantity, and is generally held by a model that is transporting inventory through the flow of the system. (See also: [Inventory Item](#inventory-item))

<a name="organization">DBA: **Organization**; model: `Organization`<br>
NDBN: **diaper bank**<br>
  The software abstraction of a diaper bank, and used interchangeably as a term.

<a name="partner">DBA: **Partner**<br>
NDBN: **Community Partner**, **Partner Organization**<br>
  An individual or Organization in the surrounding community that works directly with the families, tracks their data, and schedules distributions of diapers and sanitary supplies. Partners Request disbursements of inventory from a diaper bank, the diaper bank fulfills those requests, and then the Partner provides them to the families.

<a name="purchase">DBA: **Purchase**; model: `Purchase`<br>
  This is inventory that was purchased for cash by the diaper bank directly. We track these so that the diaper banks can report how much money they spent directly on inventory.

<a name="request">DBA: **Request**; model: `Request`<br>
  Requests are initially created by the PartnerBase application and are sent via an API. When they are received by DiaperBase, they are tracked internally and are transformed into distributions.

<a name="storage-location">DBA: **Storage Location**; model: `StorageLocation`<br>
  This is a warehouse of physical inventory, though they can be as small as someone's closet/storage room in their apartment to as big as an actual building. Storage locations are unique to each Organization and are not shared across organizations.

<a name="transfer">DBA: **Transfer**; model: `Transfer`<br>
  This is a transactional object created to track the movement of inventory from one Storage Location to another, and to leave a paper trail behind.

### PartnerBase

[PartnerBase](/rubyforgood/Partner) is a companion application built in tandem with this application. It interfaces directly with the community partners that work with the recipients of the sanitary supplies. Both applications are dependent on one another, but each address separate needs and, therefore, are maintained separately. They connect via an API. Please see the PartnerBase repository for more information.
