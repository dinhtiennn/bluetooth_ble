enum AllowRule {
  equals,
  startWith,
  endWith,
  regex,
}

class AllowService {
  AllowRule rule;
  String uuid;

  AllowService(this.uuid, {this.rule = AllowRule.equals});
}

