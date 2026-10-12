/// Rule-based FAQ logic for Lufuno, the Tingungu in-app assistant.
/// Pure keyword matching - no external API/network calls involved.
class LufunoBotService {
  static const String botName = 'Lufuno';

  static const String welcomeMessage =
      "Hi, I'm Lufuno 👋 I can help with giving, airtime, your wallet, "
      "notices, events and more. What would you like to know?";

  static const String _fallback =
      "I'm still learning that one! Try asking me about giving, airtime, "
      "your wallet, notices, events, your profile, or logging in.";

  static const List<_Topic> _topics = [
    _Topic(
      keywords: [
        'hello',
        'hi ',
        'hi!',
        'hey',
        'sawubona',
        'howzit',
        'good morning',
        'good afternoon',
        'good evening',
      ],
      response:
          "Hello there! I'm Lufuno, your Tingungu assistant. Ask me about "
          "giving, airtime, your wallet, notices, events, or your profile.",
    ),
    _Topic(
      keywords: ['give', 'giving', 'tithe', 'pledge', 'offering', 'donate'],
      response:
          "To give or pledge: open the menu (☰) → \"Give & Pledges\", choose "
          "what you're giving for, enter an amount, then pay via your "
          "Tingungu Wallet, PayFast, or Google Pay.",
    ),
    _Topic(
      keywords: ['airtime', 'recharge', 'buy airtime'],
      response:
          "You can buy airtime from the \"Airtime Top-Up\" tile on the Home "
          "screen, or via the menu → \"Buy Airtime & Utilities\". Pick a "
          "network, enter the number and amount, then choose a payment method.",
    ),
    _Topic(
      keywords: ['data bundle', 'data bundles', ' data ', 'internet bundle'],
      response:
          "Data bundles are on the way! You can preview the plans under the "
          "\"Data Bundles\" tile on Home, but purchasing isn't live yet.",
    ),
    _Topic(
      keywords: ['electricity', 'prepaid', 'token', 'meter'],
      response:
          "Electricity tokens are coming soon! Check the \"Electricity "
          "Tokens\" tile on Home to see how it will work — purchasing "
          "isn't enabled just yet.",
    ),
    _Topic(
      keywords: ['voucher', 'gift card', 'scratch card'],
      response:
          "Gift & store vouchers are coming soon! The \"Gift & Store "
          "Vouchers\" tile on Home shows a preview, but purchases aren't "
          "live yet.",
    ),
    _Topic(
      keywords: ['wallet', 'top up', 'topup', 'balance'],
      response:
          "Your Tingungu Wallet balance is shown right on the Home screen. "
          "Tap \"TOP UP\" on the wallet card, enter an amount, agree to the "
          "terms, then pay with PayFast or Google Pay.",
    ),
    _Topic(
      keywords: ['notice', 'announcement'],
      response:
          "Notices live behind the bell icon 🔔 at the top of the Home "
          "screen. Tap any notice to read it — that also marks it as read.",
    ),
    _Topic(
      keywords: ['event', 'calendar'],
      response:
          "For upcoming events, open the menu (☰) → \"Events & Calendar\", "
          "or tap \"Events\" in the bottom navigation bar.",
    ),
    _Topic(
      keywords: ['community', 'society', 'societies', 'circuit', 'minister'],
      response:
          "You can browse every district, circuit and society — along with "
          "their ministers' contact details — via the \"Community\" tab in "
          "the bottom navigation.",
    ),
    _Topic(
      keywords: ['media', ' tv', 'sermon', 'video', 'stream', 'live'],
      response:
          "Sermons and livestreams are under \"Tingungu TV & Media\" — "
          "you'll find it in the bottom navigation bar or the side menu.",
    ),
    _Topic(
      keywords: ['profile', 'account', 'avatar', 'my details'],
      response:
          "You can update your name, avatar, and other details from the "
          "menu (☰) → \"Edit Profile\".",
    ),
    _Topic(
      keywords: ['transaction', 'history'],
      response:
          "All your past payments are listed under the menu (☰) → "
          "\"Transaction History\".",
    ),
    _Topic(
      keywords: ['password', 'log in', 'login', 'sign in'],
      response:
          "Having trouble logging in? On the login screen, tap \"Forgot "
          "Password?\" and enter your email — we'll send you a reset link.",
    ),
    _Topic(
      keywords: ['register', 'sign up', 'create account', 'new account'],
      response:
          "New here? From the login screen, tap \"Register\" to create "
          "your account with your name and email.",
    ),
    _Topic(
      keywords: ['contact', 'support', 'help', 'about'],
      response:
          "For more about Tingungu, open the menu (☰) → \"About Tingungu\" "
          "to visit our website. I'm also right here for app questions!",
    ),
    _Topic(
      keywords: ['thank', 'cheers'],
      response:
          "You're very welcome! Let me know if there's anything else I can help with. 🙏",
    ),
    _Topic(
      keywords: ['bye', 'goodbye', 'see you'],
      response: "Goodbye for now! I'll be right here whenever you need me. 👋",
    ),
  ];

  static String getResponse(String message) {
    final normalized = ' ${message.toLowerCase().trim()} ';
    if (normalized.trim().isEmpty) return _fallback;

    for (final topic in _topics) {
      for (final keyword in topic.keywords) {
        if (normalized.contains(keyword)) {
          return topic.response;
        }
      }
    }
    return _fallback;
  }
}

class _Topic {
  final List<String> keywords;
  final String response;

  const _Topic({required this.keywords, required this.response});
}
