{
  outputs = {self}:
    import ./. {
      revision = self.rev or self.dirtyRev or null;
      inherit (self) lastModified;
    };
}
