# Zendesk Symptom Request Macros

Reference document for the LLM classifier. Each section below is one macro
template used by the support team when resolving symptom request tickets.

The team adapts each macro to the specific request — wording varies but the
intent and structure remain recognizable. The classifier should match
responses to these categories even when the text has been customized.

---

## Macro 1: Duplicate Symptom

Resolution: The requested symptom already exists in the database under a
different (or identical) name. Ticket is resolved immediately.

**Template:**

Hi {{ticket.requester.first_name}}, 

For your request, the suggested match is ‘SYMPTOM’. 

The best way to capture important context beyond the symptom title is to add a Note when logging the symptom. 

The reason for this is that all logged symptoms appear on your Timeline and Notes appear underneath them for easy viewing. It also helps provide more meaningful use of the Insights page when a symptom is captured under an existing, even broader symptom. 

Check out our help article on how we classify symptoms

Please don’t hesitate to reach out if anything else comes up.

Best, 

{{current_user.first_name}}
Human Health Support Team 

---

## Macro 2: Is a Condition (Not a Symptom)

Resolution: The user is describing a medical condition, not a trackable
symptom. Ticket is resolved immediately.

**Template:**

Hi {{ticket.requester.first_name}}, 

Thank you for reaching out to our support team.

The app includes 'SYMPTOM' as a Condition. To add a new condition, go to your profile in the top left, select Conditions > Add conditions.
 
To get the best out of Human, we recommend that you track the symptoms you may be experiencing related to this condition. When logging a Symptom you can add a Note to record how these symptoms are related to the condition or to simply add context. Any Note you include on a symptom is automatically added to your Timeline. When adding a new symptom, make sure you add it to the correct category of 'Ongoing impact' or 'Occasional event' so you get accurate insights.

What's the difference between "Ongoing impact" versus "Occasional event" symptoms?

If you run into any trouble or if still doesn’t quite capture what you're experiencing, please don’t hesitate to reach out, we’re here to help.

Best, 
{{current_user.first_name}}
Human Support Team 

---

## Macro 3: New Symptom — Sent to Clinical Review

Resolution: The request is for a genuinely new symptom. Ticket is put on
hold while clinical review processes it.

**Template:**

Hi {{ticket.requester.first_name}},

Thank you for reaching out, and I’m sorry you couldn’t find the relevant symptom you were looking for. We completely understand how important it is to be able to track what matters most to you.

I have flagged the requested symptom with our team to review and update. Once it’s approved, we’ll add it to our symptom database, and I’ll make sure to update you as soon as it’s available. Please note, the process can take up to one week.

If you have any questions or need further assistance, please don’t hesitate to reach out.

Best, 

{{current_user.first_name}}
Human Health Support Team

---

## Macro 4: New Symptom — Added (Follow-Up)

Resolution: Clinical review is complete and the symptom has been added.
This is the follow-up message sent when the ticket is taken off hold.

**Template:**

Hi {{ticket.requester.first_name}}, 

Just a quick update. We've added 'SYMPTOM' to the app, so you can now track it. 

Here's how to start tracking it: 

Tap the big purple '+' widget from the home screen

Select 'Symptom'

Select '+ Add a symptom'

Search for your symptom

Add any details & tap Log Symptom

Check out our help article on how we classify symptoms

And of course, feel free to reach out if anything else pops up!

Best, 

{{current_user.first_name}}
Human Health Support Team 

---

## Notes

- There will be cases where the CS agent has not used the template, but the content can still clearly be understood to be one of these three decisions
- There are likely a few edges cases that genuienly do not fit any of these cases and should be classified as OTHER
