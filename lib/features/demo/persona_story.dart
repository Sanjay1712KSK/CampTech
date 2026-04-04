import 'package:flutter/material.dart';
import 'package:guidewire_gig_ins/core/providers.dart';
import 'package:guidewire_gig_ins/core/theme.dart';

class PersonaTabStory {
  final String title;
  final String summary;
  final String focus;

  const PersonaTabStory({
    required this.title,
    required this.summary,
    required this.focus,
  });
}

class PersonaStoryBundle {
  final String key;
  final String title;
  final Color accentColor;
  final PersonaTabStory earnings;
  final PersonaTabStory insurance;
  final PersonaTabStory claims;

  const PersonaStoryBundle({
    required this.key,
    required this.title,
    required this.accentColor,
    required this.earnings,
    required this.insurance,
    required this.claims,
  });
}

PersonaStoryBundle resolvePersonaStory(UserState user) {
  final email = user.email.trim().toLowerCase();
  final phone = user.phone.trim();
  final display = user.userName.trim().toLowerCase();

  if (email == 'good.actor@gigshield.demo' || phone == '+919100000001' || display == 'good_actor') {
    return const PersonaStoryBundle(
      key: 'good_actor',
      title: 'Trusted Professional',
      accentColor: AppTheme.successColor,
      earnings: PersonaTabStory(
        title: 'Reliable earnings with a real disruption pattern',
        summary: 'This worker usually performs consistently, so visible income drops are easier to trust.',
        focus: 'Use this tab to show stable baseline income and a meaningful disruption dip.',
      ),
      insurance: PersonaTabStory(
        title: 'Insurance priced for a genuine high-risk day',
        summary: 'Premium and coverage should feel justified because the disruption is real.',
        focus: 'Best actor for showing why protection matters and why paying premium makes sense.',
      ),
      claims: PersonaTabStory(
        title: 'Strongest path to a fair payout story',
        summary: 'Real triggers plus disciplined behavior keep fraud concern low.',
        focus: 'Use this tab to explain automated approval and payout confidence.',
      ),
    );
  }

  if (email == 'bad.actor@gigshield.demo' || phone == '+919100000002' || display == 'bad_actor') {
    return const PersonaStoryBundle(
      key: 'bad_actor',
      title: 'System Gamer',
      accentColor: AppTheme.errorColor,
      earnings: PersonaTabStory(
        title: 'Irregular pattern with weaker trust signals',
        summary: 'This worker does not show a clean earning rhythm, so suspicious losses are easier to spot.',
        focus: 'Use this tab to show unstable history before explaining fraud rejection.',
      ),
      insurance: PersonaTabStory(
        title: 'Low-disruption conditions reduce the insurance case',
        summary: 'Calm conditions mean lower risk and weaker justification for a large claim later.',
        focus: 'Use this tab to explain why pricing and eligibility stay restrained.',
      ),
      claims: PersonaTabStory(
        title: 'Best example of fraud detection',
        summary: 'The system should reject or challenge claims when the environment does not support the loss story.',
        focus: 'Use this tab to explain anomaly checks, mismatch detection, and payout prevention.',
      ),
    );
  }

  if (email == 'edge.case@gigshield.demo' || phone == '+919100000003' || display == 'edge_case') {
    return const PersonaStoryBundle(
      key: 'edge_case',
      title: 'Uncertain Case',
      accentColor: AppTheme.warningColor,
      earnings: PersonaTabStory(
        title: 'Mixed signals in the earning pattern',
        summary: 'This worker shows some disruption, but not enough for an obvious decision.',
        focus: 'Use this tab to explain why context matters when the numbers are borderline.',
      ),
      insurance: PersonaTabStory(
        title: 'Pricing under moderate uncertainty',
        summary: 'Coverage still exists, but the story is less clear than a strong disruption case.',
        focus: 'Use this tab to show explainable pricing under medium risk.',
      ),
      claims: PersonaTabStory(
        title: 'Best example of a flagged review case',
        summary: 'The system should slow down and ask for caution when the evidence is mixed.',
        focus: 'Use this tab to explain review-needed outcomes rather than auto approval.',
      ),
    );
  }

  if (email == 'low.risk@gigshield.demo' || phone == '+919100000004' || display == 'low_risk') {
    return const PersonaStoryBundle(
      key: 'low_risk',
      title: 'Normal Day',
      accentColor: AppTheme.primaryColor,
      earnings: PersonaTabStory(
        title: 'Stable work on a calm day',
        summary: 'This worker has fewer disruption signs, so earnings stay steadier.',
        focus: 'Use this tab to show normal earnings with minimal stress signals.',
      ),
      insurance: PersonaTabStory(
        title: 'Lighter pricing in lower-risk conditions',
        summary: 'Calm environment and steady work keep the insurance story simple and affordable.',
        focus: 'Use this tab to explain fair pricing when the system sees less danger.',
      ),
      claims: PersonaTabStory(
        title: 'Usually not a claim-driven persona',
        summary: 'The main story here is why a low-risk day should not generate unnecessary payout activity.',
        focus: 'Use this tab to explain restraint and trust when nothing major went wrong.',
      ),
    );
  }

  if (email == 'suresh.patel@gigshield.demo' || phone == '+919100000005' || display == 'premium_success') {
    return const PersonaStoryBundle(
      key: 'premium_success',
      title: 'Premium Success User',
      accentColor: AppTheme.successColor,
      earnings: PersonaTabStory(
        title: 'Weather anomaly caused a visible earnings drop',
        summary: 'This worker already had protection in place, so today the income drop tells a complete insurance story.',
        focus: 'Use this tab to show the fall from normal earnings into disruption-led loss.',
      ),
      insurance: PersonaTabStory(
        title: 'Premium was already paid before disruption happened',
        summary: 'This is the best actor for showing that cover was active before the weather event.',
        focus: 'Use this tab to point out paid protection, valid policy history, and meaningful coverage.',
      ),
      claims: PersonaTabStory(
        title: 'Best example of automatic payout value',
        summary: 'The system sees real disruption, low fraud concern, and a payout already credited today.',
        focus: 'Use this tab to show the full protected-worker success story from premium to payout.',
      ),
    );
  }

  return const PersonaStoryBundle(
    key: 'default',
    title: 'Delivery Partner',
    accentColor: AppTheme.primaryColor,
    earnings: PersonaTabStory(
      title: 'Live earnings view',
      summary: 'Your earning trend helps the platform understand your normal work pattern.',
      focus: 'Use this tab to see baseline income and trend changes.',
    ),
    insurance: PersonaTabStory(
      title: 'Live insurance view',
      summary: 'Risk, earnings, and disruptions connect directly to premium and cover.',
      focus: 'Use this tab to understand how pricing is calculated.',
    ),
    claims: PersonaTabStory(
      title: 'Live claims view',
      summary: 'Claims connect disruption, fraud checks, payout, and trust records.',
      focus: 'Use this tab to follow the decision process end to end.',
    ),
  );
}
